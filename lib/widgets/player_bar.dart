import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/player_provider.dart';
import '../screens/now_playing_screen.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        final music = playerProvider.currentMusic;
        
        if (music == null) {
          return const SizedBox.shrink();
        }
        
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NowPlayingScreen(),
              ),
            );
          },
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withOpacity(0.3),
                ),
              ),
            ),
            child: Column(
              children: [
                // 进度条
                StreamBuilder<Duration?>(
                  stream: playerProvider.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = playerProvider.duration ?? Duration.zero;
                    final progress = duration.inMilliseconds > 0
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 0.0;
                    
                    return LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                    );
                  },
                ),
                
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        // 封面
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: music.coverUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 44,
                              height: 44,
                              color: colorScheme.surfaceContainerHighest,
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 44,
                              height: 44,
                              color: colorScheme.primaryContainer,
                              child: Icon(
                                Icons.music_note,
                                color: colorScheme.onPrimaryContainer,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // 歌曲信息
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                music.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                music.artist,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        
                        // 控制按钮
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 上一首
                            IconButton(
                              onPressed: playerProvider.playPrevious,
                              icon: const Icon(Icons.skip_previous),
                              iconSize: 28,
                              visualDensity: VisualDensity.compact,
                            ),
                            
                            // 播放/暂停
                            IconButton(
                              onPressed: playerProvider.togglePlay,
                              icon: Icon(
                                playerProvider.isPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                              ),
                              iconSize: 40,
                              color: colorScheme.primary,
                              visualDensity: VisualDensity.compact,
                            ),
                            
                            // 下一首
                            IconButton(
                              onPressed: playerProvider.playNext,
                              icon: const Icon(Icons.skip_next),
                              iconSize: 28,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
