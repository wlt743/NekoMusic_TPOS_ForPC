import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';

/// 独立桌面歌词窗口（运行在 desktop_multi_window 创建的子窗口进程中）
///
/// 独立、可交互、可拖动的浮动窗口：
/// - 始终置顶、透明圆角胶囊外观；
/// - 鼠标悬停显示工具栏（上一首/播放暂停/下一首/锁定穿透/关闭），按住可拖动；
/// - 窗口本地持有完整 LRC + 位置基准，用 100ms 定时器插值滚动（App Nap 已在
///   原生层禁用，故失焦后定时器仍运行，歌词持续滚动）。主窗口推送用于校准基准。
class LyricsWindowApp extends StatelessWidget {
  final int windowId;
  const LyricsWindowApp({super.key, required this.windowId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: LyricsWindowView(windowId: windowId),
    );
  }
}

/// 单行带时间轴歌词
class _LrcLine {
  final int timeMs;
  final String text;
  const _LrcLine(this.timeMs, this.text);
}

class LyricsWindowView extends StatefulWidget {
  final int windowId;
  const LyricsWindowView({super.key, required this.windowId});

  @override
  State<LyricsWindowView> createState() => _LyricsWindowViewState();
}

class _LyricsWindowViewState extends State<LyricsWindowView> {
  static const _native = MethodChannel('neko_lyrics_native');

  String _title = '';
  String _artist = '';

  // 解析后的歌词与位置基准
  List<_LrcLine> _lines = [];
  String _rawLyrics = '';
  int _basePositionMs = 0;
  int _baseWallClockMs = 0;
  int _durationMs = 0;
  bool _isPlaying = false;

  // 主窗口推送的「当前/下一行」，作为无时间轴歌词时的兜底显示
  String _pushedCurrent = '';
  String _pushedNext = '';
  double _pushedProgress = 0;

  // 当前显示
  String _current = '';
  String _next = '';
  double _progress = 0;

  // 样式
  Color _lyricColor = const Color(0xFFFFC800);
  double _fontSize = 24;
  double _bgOpacity = 0.7;
  double _radius = 16;
  static const Color _kNextColor = Color(0x96FFFFFF);

  bool _clickThrough = false;
  bool _hovering = false;

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      if (call.method == 'updateLyrics') {
        _handlePush(call.arguments as String);
      }
      return;
    });
    // 本地 100ms 定时器插值滚动（App Nap 已禁用，失焦也会继续跑）
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _recompute();
      // 关键：窗口失焦时 Flutter 引擎默认不会为「非活动窗口」产出新帧，
      // setState 标脏也不会重绘，导致歌词看起来停住。scheduleForcedFrame 会
      // 绕过引擎的「是否需要帧」判断，强制产出一帧，从而失焦时仍持续重绘滚动。
      WidgetsBinding.instance.scheduleForcedFrame();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyClickThrough());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _handlePush(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (!mounted) return;

    final newClickThrough = data['clickThrough'] as bool? ?? _clickThrough;

    final lyrics = data['lyrics'] as String? ?? '';
    if (lyrics != _rawLyrics) {
      _rawLyrics = lyrics;
      _lines = _parseLrc(lyrics);
    }

    _title = data['title'] as String? ?? '';
    _artist = data['artist'] as String? ?? '';
    _durationMs = (data['durationMs'] as num?)?.toInt() ?? 0;
    _isPlaying = data['isPlaying'] as bool? ?? false;

    // 校准位置基准
    _basePositionMs = (data['positionMs'] as num?)?.toInt() ?? 0;
    _baseWallClockMs = DateTime.now().millisecondsSinceEpoch;

    _pushedCurrent = data['current'] as String? ?? '';
    _pushedNext = data['next'] as String? ?? '';
    _pushedProgress =
        ((data['progress'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0);

    if (data['color'] != null) {
      _lyricColor = Color((data['color'] as num).toInt());
    }
    if (data['fontSize'] != null) {
      _fontSize = (data['fontSize'] as num).toDouble();
    }
    if (data['bgOpacity'] != null) {
      _bgOpacity = (data['bgOpacity'] as num).toDouble();
    }
    if (data['radius'] != null) {
      _radius = (data['radius'] as num).toDouble();
    }

    if (newClickThrough != _clickThrough) {
      _clickThrough = newClickThrough;
      _applyClickThrough();
    }

    _recompute();
  }

  int _effectivePositionMs() {
    if (!_isPlaying) return _basePositionMs;
    final elapsed = DateTime.now().millisecondsSinceEpoch - _baseWallClockMs;
    final pos = _basePositionMs + (elapsed < 0 ? 0 : elapsed);
    if (_durationMs > 0 && pos > _durationMs) return _durationMs;
    return pos;
  }

  void _recompute() {
    String cur;
    String next;
    double prog;

    if (_lines.isEmpty) {
      // 无时间轴歌词：使用主窗口推送的文本（不本地计算）
      cur = _pushedCurrent;
      next = _pushedNext;
      prog = _pushedProgress;
    } else {
      final pos = _effectivePositionMs();

      // 找到最后一个 timeMs <= pos 的行；若还没到第一行，则用第一行（curIdx=0）
      int curIdx = 0;
      for (int i = 0; i < _lines.length; i++) {
        if (_lines[i].timeMs <= pos) {
          curIdx = i;
        } else {
          break;
        }
      }

      cur = _lines[curIdx].text;
      final curTime = _lines[curIdx].timeMs;
      if (curIdx + 1 < _lines.length) {
        next = _lines[curIdx + 1].text;
        final nextTime = _lines[curIdx + 1].timeMs;
        prog = (nextTime > curTime && pos >= curTime)
            ? ((pos - curTime) / (nextTime - curTime)).clamp(0.0, 1.0)
            : 0.0;
      } else {
        next = '';
        final end = _durationMs > curTime ? _durationMs : curTime + 5000;
        prog = pos >= curTime
            ? ((pos - curTime) / (end - curTime)).clamp(0.0, 1.0)
            : 0.0;
      }
    }

    // 关键：有歌词时绝不回退成歌名。仅当确实拿不到任何歌词文本时才显示占位。
    if (cur.isEmpty) {
      cur = (_lines.isEmpty && _title.isNotEmpty)
          ? (_artist.isNotEmpty ? '$_title - $_artist' : _title)
          : '♪ ♪ ♪';
    }

    if (cur != _current ||
        next != _next ||
        (prog - _progress).abs() > 0.004) {
      if (mounted) {
        setState(() {
          _current = cur;
          _next = next;
          _progress = prog;
        });
      }
    }
  }

  List<_LrcLine> _parseLrc(String lyrics) {
    final out = <_LrcLine>[];
    if (lyrics.trim().isEmpty) return out;
    final tag = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
    for (final rawLine in lyrics.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final matches = tag.allMatches(line).toList();
      if (matches.isEmpty) continue;
      final text = line.replaceAll(tag, '').trim();
      if (text.isEmpty) continue; // 跳过纯时间/空行，避免歌词区出现空白行
      for (final m in matches) {
        final min = int.parse(m.group(1)!);
        final sec = int.parse(m.group(2)!);
        final fracStr = m.group(3);
        var ms = 0;
        if (fracStr != null) {
          ms = int.parse(fracStr.padRight(3, '0').substring(0, 3));
        }
        out.add(_LrcLine(min * 60000 + sec * 1000 + ms, text));
      }
    }
    out.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return out;
  }

  Future<void> _applyClickThrough() async {
    try {
      await _native.invokeMethod('setClickThrough', _clickThrough);
    } catch (_) {}
  }

  Future<void> _startDrag() async {
    try {
      await _native.invokeMethod('startDrag');
    } catch (_) {}
  }

  Future<void> _sendCommand(String command) async {
    try {
      await DesktopMultiWindow.invokeMethod(0, 'lyricsCommand', command);
    } catch (_) {}
  }

  String get _displayCurrent {
    if (_current.isNotEmpty) return _current;
    if (_title.isNotEmpty) {
      return _artist.isNotEmpty ? '$_title - $_artist' : _title;
    }
    return '♪ ♪ ♪';
  }

  @override
  Widget build(BuildContext context) {
    final showToolbar = !_clickThrough && _hovering;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        cursor: _clickThrough ? MouseCursor.defer : SystemMouseCursors.grab,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _clickThrough ? null : (_) => _startDrag(),
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(_bgOpacity.clamp(0.0, 1.0)),
                borderRadius: BorderRadius.circular(_radius),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 150),
                    child: showToolbar
                        ? _buildToolbar()
                        : const SizedBox(width: double.infinity, height: 0),
                  ),

                  Text(
                    _displayCurrent,
                    style: TextStyle(
                      color: _lyricColor,
                      fontSize: _fontSize,
                      fontWeight: FontWeight.bold,
                      shadows: const [
                        Shadow(color: Colors.black87, blurRadius: 6),
                        Shadow(color: Colors.black54, blurRadius: 12),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (_next.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _next,
                      style: TextStyle(
                        color: _kNextColor,
                        fontSize: (_fontSize * 0.66).clamp(10.0, 32.0),
                        fontWeight: FontWeight.w500,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 6),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 8),
                  _buildProgressBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final w = (maxW * _progress).clamp(0.0, maxW);
        return Align(
          alignment: Alignment.centerLeft,
          child: Stack(
            children: [
              Container(
                height: 3,
                width: maxW,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              Container(
                height: 3,
                width: w,
                decoration: BoxDecoration(
                  color: _lyricColor.withOpacity(0.86),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _title.isEmpty ? '拖动窗口移动歌词' : '$_title - $_artist',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _toolbarButton(Icons.skip_previous, () => _sendCommand('previous')),
          _toolbarButton(Icons.play_arrow, () => _sendCommand('toggle')),
          _toolbarButton(Icons.skip_next, () => _sendCommand('next')),
          const SizedBox(width: 8),
          _toolbarButton(Icons.push_pin_outlined, () {
            setState(() => _clickThrough = true);
            _applyClickThrough();
            _sendCommand('lockClickThrough');
          }, tooltip: '锁定(开启穿透)'),
          _toolbarButton(Icons.close, () => _sendCommand('close')),
        ],
      ),
    );
  }

  Widget _toolbarButton(IconData icon, VoidCallback onTap, {String? tooltip}) {
    final button = IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      iconSize: 18,
      color: Colors.white70,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: button) : button;
  }
}
