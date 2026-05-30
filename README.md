# Neko云音乐 客户端

一个轻量、美观的跨平台音乐客户端，支持 Android 和 macOS (Intel)。

## 功能特点

- 🎵 **音乐播放** - 支持在线播放、播放队列、多种播放模式
- 🎨 **自定义主题** - 8种预设主题色，支持浅色/深色/跟随系统模式
- 🎤 **桌面歌词** - macOS 桌面端支持悬浮歌词显示
- 📱 **跨平台** - 同时支持 Android 和 macOS
- 💾 **本地存储** - 自动保存登录状态和设置
- 🔍 **搜索功能** - 支持搜索音乐、歌单、歌手
- 📋 **歌单管理** - 创建、编辑、删除歌单
- ❤️ **收藏功能** - 收藏喜欢的音乐

## 截图

### Android
- 发现页面：展示热门歌曲和最新上传
- 搜索页面：搜索音乐、歌单、歌手
- 音乐库：管理收藏和歌单
- 播放界面：全屏播放器带歌词显示

### macOS
- 侧边栏导航
- 桌面歌词悬浮窗
- 迷你播放器

## 技术栈

- **Flutter** - 跨平台 UI 框架
- **Provider** - 状态管理
- **just_audio** - 音频播放
- **Hive** - 本地存储
- **Dio** - HTTP 请求
- **window_manager** - macOS 窗口管理

## 开始使用

### 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio / Xcode (用于移动端开发)

### 安装依赖

```bash
cd neko_music
flutter pub get
```

### 运行应用

#### Android
```bash
flutter run -d android
```

#### macOS
```bash
flutter run -d macos
```

### 构建发布版本

#### Android APK
```bash
flutter build apk --release
```

#### macOS App
```bash
flutter build macos --release
```

## 项目结构

```
neko_music/
├── lib/
│   ├── main.dart                 # 应用入口
│   ├── models/                   # 数据模型
│   │   ├── music.dart
│   │   ├── user.dart
│   │   └── playlist.dart
│   ├── services/                 # 服务层
│   │   ├── api_service.dart      # API 请求
│   │   └── audio_service.dart    # 音频播放
│   ├── providers/                # 状态管理
│   │   ├── theme_provider.dart   # 主题管理
│   │   ├── user_provider.dart    # 用户状态
│   │   └── player_provider.dart  # 播放器状态
│   ├── screens/                  # 页面
│   │   ├── home_screen.dart
│   │   ├── discover_page.dart
│   │   ├── search_page.dart
│   │   ├── library_page.dart
│   │   ├── profile_page.dart
│   │   ├── login_screen.dart
│   │   ├── settings_screen.dart
│   │   └── now_playing_screen.dart
│   └── widgets/                  # 组件
│       ├── player_bar.dart
│       ├── music_list_tile.dart
│       └── desktop_lyrics_overlay.dart
├── android/                      # Android 配置
├── macos/                        # macOS 配置
└── pubspec.yaml                  # 项目配置
```

## API 文档

本客户端基于 [Neko云音乐 API](https://github.com/FantasyNetworkCN/NekoMusicDocs)。

基础 URL: `https://music.cnmsb.xin`

## 主要功能

### 音乐播放
- 在线流式播放
- 播放/暂停/上一首/下一首
- 进度拖动
- 播放模式：顺序、循环、单曲、随机

### 主题定制
- 浅色模式
- 深色模式
- 跟随系统
- 8种预设主题色

### 桌面歌词 (macOS)
- 悬浮窗显示
- 可拖拽位置
- 显示当前和下一行歌词
- 鼠标悬浮显示控制按钮

### 用户功能
- 登录/注册
- 收藏音乐
- 创建/管理歌单
- 每日推荐

## 注意事项

1. 使用本 API 需遵守 [Neko云音乐 API 文档](https://github.com/FantasyNetworkCN/NekoMusicDocs) 规定的 AGPL 协议
2. 必须开源并保留 Neko云音乐 署名及源码链接，衍生作品须以相同的 AGPL 协议发布
3. Token 有效期为 30 天

## 许可证

本项目依据 [Neko云音乐 API 文档](https://github.com/FantasyNetworkCN/NekoMusicDocs) 的规定，采用 **GNU Affero General Public License v3.0 (AGPL-3.0)** 开源协议发布。

这意味着你可以自由地使用、修改和分发本软件，但：

- 任何基于本项目的衍生作品也必须以 AGPL-3.0 协议开源
- 必须保留原始版权声明、Neko云音乐 署名及源码链接
- 若通过网络向用户提供本软件（或其修改版）的服务，必须向这些用户公开对应的源代码
- 不提供任何形式的担保

完整协议内容详见 [LICENSE](LICENSE) 文件。

## 联系方式

如有问题或建议，请联系：support@cnmsb.xin
