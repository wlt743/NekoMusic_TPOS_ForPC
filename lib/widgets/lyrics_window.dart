import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';

/// 独立桌面歌词窗口（运行在 desktop_multi_window 创建的子窗口进程中）
///
/// 该窗口是一个独立的系统窗口，可自由移动到主应用窗口范围之外，
/// 不会被主窗口边界裁切。主窗口通过 method channel 向其推送歌词文本。
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

class LyricsWindowView extends StatefulWidget {
  final int windowId;
  const LyricsWindowView({super.key, required this.windowId});

  @override
  State<LyricsWindowView> createState() => _LyricsWindowViewState();
}

class _LyricsWindowViewState extends State<LyricsWindowView> {
  String _currentLyric = '♪ ♪ ♪';
  String _nextLyric = '';
  String _title = '';
  String _artist = '';
  bool _isPlaying = false;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    // 接收主窗口推送的歌词/播放状态
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      if (call.method == 'updateLyrics') {
        final data = jsonDecode(call.arguments as String) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _currentLyric = (data['current'] as String?)?.isNotEmpty == true
                ? data['current'] as String
                : '♪ ♪ ♪';
            _nextLyric = data['next'] as String? ?? '';
            _title = data['title'] as String? ?? '';
            _artist = data['artist'] as String? ?? '';
            _isPlaying = data['isPlaying'] as bool? ?? false;
          });
        }
      }
      return;
    });
  }

  // 向主窗口回传控制指令（上一首/播放暂停/下一首/关闭）
  Future<void> _sendCommand(String command) async {
    await DesktopMultiWindow.invokeMethod(0, 'lyricsCommand', command);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          // 拖动整个窗口（系统级移动，可移出主应用范围）
          onPanStart: (_) => DesktopMultiWindow.invokeMethod(
            widget.windowId,
            'startDrag',
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(_isHovering ? 0.85 : 0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 工具栏（悬浮显示）
                AnimatedOpacity(
                  opacity: _isHovering ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: SizedBox(
                    height: _isHovering ? 32 : 0,
                    child: _isHovering
                        ? Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _title.isEmpty ? '' : '$_title - $_artist',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _sendCommand('previous'),
                                icon: const Icon(Icons.skip_previous),
                                iconSize: 18,
                                color: Colors.white60,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _sendCommand('toggle'),
                                icon: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                ),
                                iconSize: 22,
                                color: Colors.white,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _sendCommand('next'),
                                icon: const Icon(Icons.skip_next),
                                iconSize: 18,
                                color: Colors.white60,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _sendCommand('close'),
                                icon: const Icon(Icons.close),
                                iconSize: 18,
                                color: Colors.white60,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),

                // 当前歌词
                Text(
                  _currentLyric,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // 下一行歌词
                if (_nextLyric.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _nextLyric,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
