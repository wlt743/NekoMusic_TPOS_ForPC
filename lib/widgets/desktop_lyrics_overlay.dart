import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import '../providers/player_provider.dart';

/// 桌面歌词悬浮窗
/// 仅在桌面平台（macOS/Windows/Linux）显示
class DesktopLyricsOverlay extends StatefulWidget {
  const DesktopLyricsOverlay({super.key});

  @override
  State<DesktopLyricsOverlay> createState() => _DesktopLyricsOverlayState();
}

class _DesktopLyricsOverlayState extends State<DesktopLyricsOverlay> {
  Offset _position = const Offset(100, 100);
  bool _isDragging = false;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    // 初始位置设置在屏幕底部中央
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      setState(() {
        _position = Offset(
          (size.width - 600) / 2,
          size.height - 150,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // 仅桌面平台显示
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
      return const SizedBox.shrink();
    }

    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        final currentLyric = playerProvider.currentLyricText;
        final nextLyric = playerProvider.nextLyricText;
        final music = playerProvider.currentMusic;

        if (music == null) {
          return const SizedBox.shrink();
        }

        return Positioned(
          left: _position.dx,
          top: _position.dy,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            child: GestureDetector(
              onPanStart: (_) => setState(() => _isDragging = true),
              onPanEnd: (_) => setState(() => _isDragging = false),
              onPanUpdate: (details) {
                setState(() {
                  final screen = MediaQuery.of(context).size;
                  const overlayWidth = 600.0;
                  // 估算歌词窗高度，约束在窗口可视范围内，避免拖出后被裁切隐藏
                  const overlayHeight = 120.0;
                  final next = _position + details.delta;
                  _position = Offset(
                    next.dx.clamp(0.0, (screen.width - overlayWidth).clamp(0.0, double.infinity)),
                    next.dy.clamp(0.0, (screen.height - overlayHeight).clamp(0.0, double.infinity)),
                  );
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 600,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: _isHovering || _isDragging
                      ? Colors.black.withOpacity(0.85)
                      : Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 工具栏（悬浮时显示）
                    AnimatedOpacity(
                      opacity: _isHovering ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: _isHovering ? 32 : 0,
                        child: Row(
                          children: [
                            // 歌曲信息
                            Expanded(
                              child: Text(
                                '${music.title} - ${music.artist}',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // 播放控制
                            IconButton(
                              onPressed: playerProvider.playPrevious,
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
                              onPressed: playerProvider.togglePlay,
                              icon: Icon(
                                playerProvider.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
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
                              onPressed: playerProvider.playNext,
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
                            // 关闭按钮
                            IconButton(
                              onPressed: () {
                                playerProvider.setShowDesktopLyrics(false);
                              },
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
                        ),
                      ),
                    ),
                    
                    // 当前歌词
                    Text(
                      currentLyric.isNotEmpty ? currentLyric : '♪ ♪ ♪',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // 下一行歌词
                    if (nextLyric.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        nextLyric,
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
      },
    );
  }
}

/// 简化版桌面歌词（单行）
class DesktopLyricsSimple extends StatefulWidget {
  const DesktopLyricsSimple({super.key});

  @override
  State<DesktopLyricsSimple> createState() => _DesktopLyricsSimpleState();
}

class _DesktopLyricsSimpleState extends State<DesktopLyricsSimple> {
  Offset _position = const Offset(100, 100);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      setState(() {
        _position = Offset(
          (size.width - 500) / 2,
          size.height - 80,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        final currentLyric = playerProvider.currentLyricText;

        if (currentLyric.isEmpty) {
          return const SizedBox.shrink();
        }

        return Positioned(
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _position += details.delta;
              });
            },
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                currentLyric,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}
