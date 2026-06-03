import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/netease_import.dart';
import '../models/playlist.dart';
import '../services/api_service.dart';
import '../providers/user_provider.dart';

enum PlaylistImportSource {
  netease,
  qqMusic,
}

extension _PlaylistImportSourceText on PlaylistImportSource {
  String get displayName {
    switch (this) {
      case PlaylistImportSource.netease:
        return '网易云';
      case PlaylistImportSource.qqMusic:
        return 'QQ 音乐';
    }
  }

  String get title => '导入$displayName歌单';

  String get inputDescription => '输入$displayName歌单链接或 ID，将歌曲匹配并导入到本地歌单';
}

/// 外部歌单导入对话框
///
/// 复刻自 NekoMusicForPc 的 NeteaseImportDialog：
/// 1. 输入歌单链接/ID → 拉取歌单详情
/// 2. 选择导入目标（我喜欢 / 已有歌单 / 新建歌单）
/// 3. 批量搜索匹配 → 批量添加，全程展示进度
///
/// 导入完成后通过 Navigator.pop 返回 true，调用方可据此刷新列表。
class NeteaseImportDialog extends StatefulWidget {
  final PlaylistImportSource source;

  const NeteaseImportDialog({
    super.key,
    this.source = PlaylistImportSource.netease,
  });

  /// 便捷入口：弹出对话框，返回是否有歌曲成功导入。
  static Future<bool> show(
    BuildContext context, {
    PlaylistImportSource source = PlaylistImportSource.netease,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NeteaseImportDialog(source: source),
    );
    return result == true;
  }

  @override
  State<NeteaseImportDialog> createState() => _NeteaseImportDialogState();
}

// 目标歌单的特殊标识（与 PC 端 kImportTarget* 对应）
const int _targetFavorites = -1;
const int _targetNewPlaylist = -2;

class _NeteaseImportDialogState extends State<NeteaseImportDialog> {
  final _inputController = TextEditingController();
  final _newPlaylistController = TextEditingController();

  Object? _playlist;
  List<Playlist> _userPlaylists = [];
  int _targetId = _targetFavorites;

  bool _fetching = false;
  bool _importing = false;
  double _progress = 0;
  String? _statusText;
  String? _errorText;
  bool _completed = false;

  @override
  void dispose() {
    _inputController.dispose();
    _newPlaylistController.dispose();
    super.dispose();
  }

  void _setError(String? msg) {
    setState(() => _errorText = msg);
  }

  String get _playlistName {
    final playlist = _playlist;
    if (playlist is NeteasePlaylistInfo) return playlist.name;
    if (playlist is QqMusicPlaylistInfo) return playlist.name;
    return '';
  }

  int get _playlistTrackCount {
    final playlist = _playlist;
    if (playlist is NeteasePlaylistInfo) {
      return playlist.trackCount > 0
          ? playlist.trackCount
          : playlist.tracks.length;
    }
    if (playlist is QqMusicPlaylistInfo) {
      return playlist.trackCount > 0
          ? playlist.trackCount
          : playlist.tracks.length;
    }
    return 0;
  }

  List<NeteaseSearchItem> get _searchItems {
    final playlist = _playlist;
    if (playlist is NeteasePlaylistInfo) {
      return playlist.tracks
          .map((t) => NeteaseSearchItem(title: t.name, artist: t.artist))
          .toList();
    }
    if (playlist is QqMusicPlaylistInfo) {
      return playlist.tracks
          .map((t) => NeteaseSearchItem(title: t.name, artist: t.artist))
          .toList();
    }
    return const [];
  }

  Future<void> _fetchPlaylist() async {
    final input = _inputController.text;
    final api = context.read<ApiService>();
    final userProvider = context.read<UserProvider>();

    Object playlist;
    String playlistName;
    bool isEmpty;

    final isQqMusic = widget.source == PlaylistImportSource.qqMusic;
    final idStr = isQqMusic
        ? ApiService.parseQqMusicPlaylistId(input)
        : ApiService.parseNeteasePlaylistId(input);
    final neteaseId = int.tryParse(idStr ?? '');
    if (idStr == null ||
        (!isQqMusic && (neteaseId == null || neteaseId <= 0))) {
      _setError('无法解析歌单链接或 ID，请检查输入');
      return;
    }

    setState(() {
      _errorText = null;
      _fetching = true;
    });

    try {
      if (isQqMusic) {
        final qqPlaylist = await api.fetchQqMusicPlaylist(idStr);
        playlist = qqPlaylist;
        playlistName = qqPlaylist.name;
        isEmpty = qqPlaylist.tracks.isEmpty;
      } else {
        final neteasePlaylist = await api.fetchNeteasePlaylist(neteaseId!);
        playlist = neteasePlaylist;
        playlistName = neteasePlaylist.name;
        isEmpty = neteasePlaylist.tracks.isEmpty;
      }

      if (isEmpty) {
        _setError('歌单为空');
        return;
      }

      if (!userProvider.isLoggedIn) {
        setState(() => _playlist = playlist);
        _setError('请先登录后再导入');
        return;
      }

      // 拉取用户歌单作为导入目标
      final playlists = await api.getMyPlaylists();

      if (!mounted) return;
      setState(() {
        _playlist = playlist;
        _userPlaylists = playlists;
        _targetId = _targetFavorites;
        _newPlaylistController.text = playlistName;
      });
    } on NeteaseImportException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('获取歌单失败');
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _startImport() async {
    final playlist = _playlist;
    final searchItems = _searchItems;
    if (playlist == null || searchItems.isEmpty) {
      _setError('没有可导入的歌曲');
      return;
    }

    if (_targetId == _targetNewPlaylist &&
        _newPlaylistController.text.trim().isEmpty) {
      _setError('请输入新歌单名称');
      return;
    }

    setState(() {
      _errorText = null;
      _importing = true;
      _progress = 0.05;
      _statusText = '正在搜索匹配歌曲...';
    });

    final api = context.read<ApiService>();

    try {
      // 1. 批量搜索匹配
      final searchResult = await api.batchSearchNeteaseMusic(
        searchItems,
        onProgress: (p) {
          if (mounted) {
            // 搜索阶段占 5% ~ 55%
            setState(() => _progress = 0.05 + p * 0.5);
          }
        },
      );

      // 未匹配到任何歌曲：直接跳过添加，提示结果（曲库无此歌曲时跳过）
      if (searchResult.matchedMusicIds.isEmpty) {
        setState(() {
          _completed = true;
          _progress = 1.0;
          _statusText = '没有可导入的歌曲：${searchResult.failCount} 首在曲库中未找到，已跳过';
        });
        return;
      }

      // 2. 解析目标歌单 ID（新建时先创建）
      setState(() {
        _progress = 0.6;
        _statusText = '正在添加 ${searchResult.matchedMusicIds.length} 首歌曲...';
      });

      BatchAddResult addResult;
      if (_targetId == _targetFavorites) {
        addResult = await api.batchAddFavorites(searchResult.matchedMusicIds);
      } else {
        int resolvedId = _targetId;
        if (_targetId == _targetNewPlaylist) {
          setState(() => _statusText = '正在创建歌单...');
          final created = await api.createNeteasePlaylist(
            _newPlaylistController.text.trim(),
          );
          resolvedId = created.id;
          setState(() {
            _statusText = '正在添加 ${searchResult.matchedMusicIds.length} 首歌曲...';
          });
        }
        addResult = await api.batchAddMusicToPlaylist(
          resolvedId,
          searchResult.matchedMusicIds,
        );
      }

      setState(() => _progress = 1.0);

      // 走到这里说明没有抛出鉴权/网络错误（_ensureNotAuthError 会抛出真正失败），
      // 因此一律视为「已处理」：已存在的曲目按跳过统计，不再误报失败。
      final matchedTotal = searchResult.matchedMusicIds.length;
      final addedCount = addResult.addedCount;
      // 已在目标中而被跳过的数量 = 匹配总数 - 实际新增数（下限 0）
      final skippedExisting =
          (matchedTotal - addedCount) < 0 ? 0 : (matchedTotal - addedCount);

      // 汇总：成功导入 / 已存在跳过 / 曲库未匹配跳过
      final parts = <String>['成功导入 $addedCount 首'];
      if (skippedExisting > 0) parts.add('已存在跳过 $skippedExisting 首');
      if (searchResult.failCount > 0) {
        parts.add('未匹配跳过 ${searchResult.failCount} 首');
      }

      setState(() {
        _completed = true;
        _statusText = '导入完成：${parts.join('，')}';
      });
    } on NeteaseImportException catch (e) {
      _setError(e.message);
      setState(() => _importing = false);
    } catch (e) {
      // 显示真实错误，便于定位（而不是笼统的「导入失败」）
      _setError('导入失败：$e');
      setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasPlaylist = _playlist != null;

    return AlertDialog(
      title: Text(widget.source.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.source.inputDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // 输入 + 获取按钮
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: !_importing,
                      decoration: const InputDecoration(
                        hintText: '歌单链接或 ID',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: (_) => _fetching ? null : _fetchPlaylist(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed:
                        (_fetching || _importing) ? null : _fetchPlaylist,
                    child: _fetching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('获取'),
                  ),
                ],
              ),

              // 歌单信息
              if (hasPlaylist) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.queue_music, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '歌单：$_playlistName（共 $_playlistTrackCount 首）',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 目标选择
              if (hasPlaylist && !_completed) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('导入到：'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _targetId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: _targetFavorites,
                            child: Text('我喜欢的音乐'),
                          ),
                          ..._userPlaylists.map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                p.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: _targetNewPlaylist,
                            child: Text('新建歌单'),
                          ),
                        ],
                        onChanged: _importing
                            ? null
                            : (v) {
                                if (v == null) return;
                                setState(() {
                                  _targetId = v;
                                  if (v == _targetNewPlaylist &&
                                      _newPlaylistController.text
                                          .trim()
                                          .isEmpty) {
                                    _newPlaylistController.text = _playlistName;
                                  }
                                });
                              },
                      ),
                    ),
                  ],
                ),

                // 新建歌单名称输入
                if (_targetId == _targetNewPlaylist) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPlaylistController,
                    enabled: !_importing,
                    decoration: const InputDecoration(
                      labelText: '新歌单名称',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ],

              // 进度
              if (_importing || _completed) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 8,
                  ),
                ),
                if (_statusText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _statusText!,
                    style: TextStyle(
                      fontSize: 13,
                      color: _completed
                          ? Colors.green
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],

              // 错误
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _importing ? null : () => Navigator.of(context).pop(_completed),
          child: Text(_completed ? '完成' : '关闭'),
        ),
        if (hasPlaylist && !_completed)
          FilledButton(
            onPressed: _importing ? null : _startImport,
            child: const Text('开始导入'),
          ),
      ],
    );
  }
}
