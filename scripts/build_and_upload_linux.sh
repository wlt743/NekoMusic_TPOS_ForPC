#!/usr/bin/env bash
#
# 本地构建 Linux 版本并上传到 GitHub Release 的脚本。
#
# 用途：当 GitHub Actions 不可用时（例如账户级 Actions 被禁用），
#       在任意 Linux 环境（物理机 / 虚拟机 / WSL2 / Docker 容器）执行本脚本，
#       即可构建 Linux 桌面版并把产物追加到指定的 Release。
#
# 前置要求：
#   - 已安装 Flutter（stable channel）并加入 PATH
#   - 具备 sudo 安装系统依赖的权限（或提前装好下方依赖）
#   - 一个有 repo 权限的 GitHub Token，通过环境变量 GITHUB_TOKEN 传入
#
# 用法：
#   GITHUB_TOKEN=ghp_xxx ./scripts/build_and_upload_linux.sh [TAG]
#   # TAG 默认取 pubspec.yaml 中的 version，前面加 'v'，例如 v2.0.1
#
set -euo pipefail

REPO="bilibilicraft/NekoMusicAndroid_Macos"

# 切到脚本所在项目根目录（scripts 的上一级）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# 解析版本与 tag
VERSION="$(grep '^version:' pubspec.yaml | sed 's/version:[[:space:]]*//' | tr -d '[:space:]')"
TAG="${1:-v${VERSION}}"
echo "==> 项目目录: $PROJECT_DIR"
echo "==> 版本: $VERSION  Tag: $TAG"

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "ERROR: 请通过环境变量 GITHUB_TOKEN 提供具备 repo 权限的 GitHub Token。" >&2
  exit 1
fi

# 1) 安装 Linux 构建依赖（Debian/Ubuntu）。其他发行版请自行替换包管理器。
if command -v apt-get >/dev/null 2>&1; then
  echo "==> 安装系统依赖 (apt-get)"
  sudo apt-get update
  sudo apt-get install -y \
    clang cmake ninja-build pkg-config \
    libgtk-3-dev liblzma-dev \
    libmpv-dev mpv \
    curl jq
else
  echo "WARN: 未检测到 apt-get，请确保已手动安装: clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libmpv-dev mpv curl jq"
fi

# 2) 启用 Linux 桌面并按需生成 linux/ 工程
flutter config --enable-linux-desktop
if [ ! -d linux ]; then
  echo "==> 生成 linux/ 平台工程"
  flutter create --platforms=linux .
fi

# 3) 获取依赖并构建
flutter pub get
echo "==> 构建 Linux release"
flutter build linux --release

# 4) 打包产物
BUNDLE_DIR="build/linux/x64/release/bundle"
OUT="NekoMusic-${VERSION}-linux-x64.tar.gz"
echo "==> 打包 $OUT"
tar -czf "$OUT" -C "$BUNDLE_DIR" .
ls -lh "$OUT"

# 5) 取得 Release ID（若不存在则创建）
api() { curl -s -H "Authorization: token ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" "$@"; }

echo "==> 查询 Release $TAG"
REL_JSON="$(api "https://api.github.com/repos/${REPO}/releases/tags/${TAG}")"
REL_ID="$(echo "$REL_JSON" | jq -r '.id // empty')"

if [ -z "$REL_ID" ]; then
  echo "==> Release 不存在，创建 $TAG"
  REL_JSON="$(api -X POST -d "{\"tag_name\":\"${TAG}\",\"name\":\"${TAG}\",\"draft\":false,\"prerelease\":false}" \
    "https://api.github.com/repos/${REPO}/releases")"
  REL_ID="$(echo "$REL_JSON" | jq -r '.id // empty')"
fi

if [ -z "$REL_ID" ]; then
  echo "ERROR: 无法获取或创建 Release。响应：" >&2
  echo "$REL_JSON" >&2
  exit 1
fi
echo "==> Release ID: $REL_ID"

# 6) 若同名资产已存在则先删除，避免 422 冲突
EXIST_ASSET_ID="$(api "https://api.github.com/repos/${REPO}/releases/${REL_ID}/assets" \
  | jq -r --arg n "$OUT" '.[] | select(.name==$n) | .id' | head -n1)"
if [ -n "$EXIST_ASSET_ID" ]; then
  echo "==> 删除已存在的同名资产 (id=$EXIST_ASSET_ID)"
  api -X DELETE "https://api.github.com/repos/${REPO}/releases/assets/${EXIST_ASSET_ID}" >/dev/null
fi

# 7) 上传
echo "==> 上传 $OUT 到 Release"
UP_JSON="$(curl -s --max-time 600 -X POST \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Content-Type: application/gzip" \
  --data-binary @"${OUT}" \
  "https://uploads.github.com/repos/${REPO}/releases/${REL_ID}/assets?name=${OUT}")"

echo "$UP_JSON" | jq '{name, state, size, browser_download_url, message}'
echo "==> 完成"
