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
  StreamSubscription<Duration?>? _positionSub;
  bool _listening = false;
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

    // 监听播放器变化（切歌 / 样式 / 穿透开关），变化时立即推送，
    // 避免只靠定时推送导致切歌后歌词短暂不更新。
    if (!_listening) {
      _player.addListener(_pushOnce);
      _listening = true;
    }

    // 首次打开：连续多次推送，确保子窗口的 method handler 注册完成后能收到数据，
    // 解决「第一次打开歌词不滚动」（首推早于子窗口监听导致丢失）。
    _pushOnce();
    for (final ms in [80, 200, 400, 700, 1000, 1500]) {
      Future.delayed(Duration(milliseconds: ms), () {
        if (_window != null) _pushOnce();
      });
    }

    // 订阅音频播放位置流：切歌/跳转时校准歌词窗口的本地时钟基准。
    _positionSub?.cancel();
    _positionSub = _player.positionStream.listen((_) {
      _player.refreshCurrentLyricFromPosition();
      _pushOnce();
    });

    // 兜底定时器：定期校准（子窗口本身用本地 100ms 定时器插值滚动，此处仅校准基准）。
    _pushTimer?.cancel();
    _pushTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _player.refreshCurrentLyricFromPosition();
      _pushOnce();
    });
  }

  /// 关闭独立桌面歌词窗口
  Future<void> close() async {
    _pushTimer?.cancel();
    _pushTimer = null;
    _positionSub?.cancel();
    _positionSub = null;
    if (_listening) {
      _player.removeListener(_pushOnce);
      _listening = false;
    }
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
      // 当前歌词行进度（0.0~1.0），用于胶囊底部进度条（参照 PC 端）
      'progress': _player.currentLineProgress,
      // 完整 LRC + 播放位置/状态：让歌词窗口本地按时间计算并平滑滚动
      // （参照 PC 端 DesktopLrc：窗口自己持有歌词与位置，用定时器驱动）
      'lyrics': _player.currentLyrics ?? '',
      'positionMs': _player.position.inMilliseconds,
      'durationMs': _player.duration?.inMilliseconds ?? 0,
      'isPlaying': _player.isPlaying,
      // 桌面歌词样式：颜色、字号、背景透明度、圆角
      'color': _player.lyricColor.value,
      'fontSize': _player.lyricFontSize,
      'bgOpacity': _player.lyricBackgroundOpacity,
      'radius': _player.lyricCornerRadius,
      // 点击穿透开关（false=可交互可拖动）
      'clickThrough': _player.lyricsClickThrough,
    });
    DesktopMultiWindow.invokeMethod(w.windowId, 'updateLyrics', payload)
        .catchError((_) {});
  }

  // 接收歌词子窗口回传的控制指令（上一首/播放暂停/下一首/关闭/锁定穿透）
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
          case 'lockClickThrough':
            _player.setLyricsClickThrough(true);
            break;
        }
      }
      return;
    });
  }
}
