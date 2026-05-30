import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:desktop_multi_window/desktop_multi_window.dart';

import '../providers/player_provider.dart';

/// 桌面歌词独立窗口管理器（主窗口侧）
///
/// 负责创建/销毁独立的桌面歌词子窗口，并把当前歌词、播放状态实时推送给它；
/// 同时接收子窗口回传的播放控制指令。
class LyricsWindowManager {
  LyricsWindowManager(this._player);

  final PlayerProvider _player;

  WindowController? _window;
  Timer? _pushTimer;
  bool _handlerRegistered = false;

  bool get isOpen => _window != null;

  /// 打开独立桌面歌词窗口
  Future<void> open() async {
    if (_window != null) return;

    _registerCommandHandler();

    final controller = await DesktopMultiWindow.createWindow(jsonEncode({
      'type': 'lyrics',
    }));
    controller
      ..setFrame(const Rect.fromLTWH(100, 100, 620, 160))
      ..setTitle('桌面歌词')
      ..show();

    _window = controller;

    // 立即推送一次并启动定时推送
    _pushOnce();
    _pushTimer?.cancel();
    _pushTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      _pushOnce();
    });
  }

  /// 关闭独立桌面歌词窗口
  Future<void> close() async {
    _pushTimer?.cancel();
    _pushTimer = null;
    final w = _window;
    _window = null;
    if (w != null) {
      try {
        await w.close();
      } catch (_) {}
    }
  }

  void _pushOnce() {
    final w = _window;
    if (w == null) return;
    final payload = jsonEncode({
      'current': _player.currentLyricText,
      'next': _player.nextLyricText,
      'title': _player.currentMusic?.title ?? '',
      'artist': _player.currentMusic?.artist ?? '',
      'isPlaying': _player.isPlaying,
    });
    DesktopMultiWindow.invokeMethod(w.windowId, 'updateLyrics', payload)
        .catchError((_) {});
  }

  void _registerCommandHandler() {
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      if (call.method == 'lyricsCommand') {
        final cmd = call.arguments as String;
        switch (cmd) {
          case 'previous':
            await _player.playPrevious();
            break;
          case 'toggle':
            await _player.togglePlay();
            break;
          case 'next':
            await _player.playNext();
            break;
          case 'close':
            _player.setShowDesktopLyrics(false);
            break;
        }
      }
      return;
    });
  }
}
