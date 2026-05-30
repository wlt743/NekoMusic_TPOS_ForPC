import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

import '../providers/player_provider.dart';
import '../services/audio_service.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        final music = playerProvider.currentMusic;
        
        if (music == null) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
            ),
            body: const Center(
              child: Text('暂无播放'),
            ),
          );
        }
        
        // macOS 隐藏了原生标题栏，红绿灯位于左上角，需为返回按钮留出空间
        final isMacOS = Platform.isMacOS;
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: isMacOS ? 56 : kToolbarHeight,
            leadingWidth: isMacOS ? 96 : null,
            leading: Padding(
              padding: EdgeInsets.only(left: isMacOS ? 72 : 0),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.keyboard_arrow_down, size: 32),
              ),
            ),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: isMacOS ? 12 : 0),
                child: IconButton(
                  onPressed: () {
                    _showMoreOptions(context, playerProvider);
                  },
                  icon: const Icon(Icons.more_vert),
                ),
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.surface,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 1),
                  
                  // 封面
                  Container(
                    width: size.width * 0.75,
                    height: size.width * 0.75,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withOpacity(0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CachedNetworkImage(
                        imageUrl: music.coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.music_note,
                            size: 80,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const Spacer(flex: 1),
                  
                  // 歌曲信息
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        Text(
                          music.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          music.artist,
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // 歌词显示
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          playerProvider.currentLyricText.isNotEmpty
                              ? playerProvider.currentLyricText
                              : '暂无歌词',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        if (playerProvider.nextLyricText.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            playerProvider.nextLyricText,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 进度条
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: StreamBuilder<Duration?>(
                      stream: playerProvider.positionStream,
                      builder: (context, snapshot) {
                        final position = snapshot.data ?? Duration.zero;
                        final duration = playerProvider.duration ?? Duration.zero;
                        
                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                              ),
                              child: Slider(
                                value: position.inMilliseconds.toDouble().clamp(
                                  0,
                                  duration.inMilliseconds.toDouble(),
                                ),
                                min: 0,
                                max: duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                                onChanged: (value) {
                                  playerProvider.seek(Duration(milliseconds: value.toInt()));
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 控制按钮
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 播放模式
                        IconButton(
                          onPressed: () {
                            playerProvider.togglePlayMode();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(playerProvider.playModeName),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          icon: Icon(playerProvider.playModeIcon),
                          iconSize: 28,
                        ),
                        
                        // 上一首
                        IconButton(
                          onPressed: playerProvider.playPrevious,
                          icon: const Icon(Icons.skip_previous),
                          iconSize: 40,
                        ),
                        
                        // 播放/暂停
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary,
                          ),
                          child: IconButton(
                            onPressed: playerProvider.togglePlay,
                            icon: Icon(
                              playerProvider.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: colorScheme.onPrimary,
                            ),
                            iconSize: 40,
                          ),
                        ),
                        
                        // 下一首
                        IconButton(
                          onPressed: playerProvider.playNext,
                          icon: const Icon(Icons.skip_next),
                          iconSize: 40,
                        ),
                        
                        // 播放列表
                        IconButton(
                          onPressed: () => _showPlaylist(context, playerProvider),
                          icon: const Icon(Icons.queue_music),
                          iconSize: 28,
                        ),
                      ],
                    ),
                  ),
                  
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showMoreOptions(BuildContext context, PlayerProvider playerProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('收藏'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 收藏功能
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('添加到歌单'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 添加到歌单
              },
            ),
            ListTile(
              leading: Icon(
                playerProvider.showDesktopLyrics
                    ? Icons.lyrics
                    : Icons.lyrics_outlined,
              ),
              title: Text(
                playerProvider.showDesktopLyrics ? '关闭桌面歌词' : '开启桌面歌词',
              ),
              onTap: () {
                playerProvider.toggleDesktopLyrics();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 分享功能
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showPlaylist(BuildContext context, PlayerProvider playerProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    '播放队列',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${playerProvider.playlist.length})',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      playerProvider.clearPlaylist();
                      Navigator.pop(context);
                    },
                    child: const Text('清空'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // 列表
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: playerProvider.playlist.length,
                itemBuilder: (context, index) {
                  final music = playerProvider.playlist[index];
                  final isPlaying = index == playerProvider.currentIndex;
                  
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: music.coverUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 40,
                          height: 40,
                          color: colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.music_note, size: 20),
                        ),
                      ),
                    ),
                    title: Text(
                      music.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isPlaying ? colorScheme.primary : null,
                        fontWeight: isPlaying ? FontWeight.bold : null,
                      ),
                    ),
                    subtitle: Text(
                      music.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isPlaying
                            ? colorScheme.primary.withOpacity(0.7)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: isPlaying
                        ? Icon(
                            Icons.equalizer,
                            color: colorScheme.primary,
                          )
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              playerProvider.removeFromPlaylist(index);
                            },
                          ),
                    onTap: () {
                      playerProvider.playList(
                        playerProvider.playlist,
                        startIndex: index,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
