import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/music.dart';

class MusicListTile extends StatelessWidget {
  final Music music;
  final int? index;
  final bool isPlaying;
  final bool showFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final Widget? trailing;

  const MusicListTile({
    super.key,
    required this.music,
    this.index,
    this.isPlaying = false,
    this.showFavorite = false,
    this.onTap,
    this.onFavoriteToggle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // 序号
            if (index != null)
              SizedBox(
                width: 32,
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 14,
                    color: isPlaying 
                        ? colorScheme.primary 
                        : colorScheme.onSurfaceVariant,
                    fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            
            // 封面
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: music.coverUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 48,
                  height: 48,
                  color: colorScheme.surfaceContainerHighest,
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.music_note,
                    color: colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // 歌曲信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    music.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                      color: isPlaying ? colorScheme.primary : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          music.artist,
                          style: TextStyle(
                            fontSize: 12,
                            color: isPlaying 
                                ? colorScheme.primary.withOpacity(0.7)
                                : colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (music.album != null && music.album!.isNotEmpty) ...[
                        Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            music.album!,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // 时长
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                music.durationFormatted,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            
            // 收藏按钮
            if (showFavorite)
              IconButton(
                onPressed: onFavoriteToggle,
                icon: const Icon(Icons.favorite, size: 20),
                color: colorScheme.error,
                visualDensity: VisualDensity.compact,
              ),
            
            // 自定义尾部
            if (trailing != null) trailing!,
            
            // 正在播放指示
            if (isPlaying && trailing == null && !showFavorite)
              Icon(
                Icons.equalizer,
                color: colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// 带更多选项的音乐列表项
class MusicListTileWithMenu extends StatelessWidget {
  final Music music;
  final int? index;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onFavorite;

  const MusicListTileWithMenu({
    super.key,
    required this.music,
    this.index,
    this.isPlaying = false,
    this.onTap,
    this.onPlay,
    this.onAddToQueue,
    this.onAddToPlaylist,
    this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return MusicListTile(
      music: music,
      index: index,
      isPlaying: isPlaying,
      onTap: onTap,
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20),
        onSelected: (value) {
          switch (value) {
            case 'play':
              onPlay?.call();
              break;
            case 'queue':
              onAddToQueue?.call();
              break;
            case 'playlist':
              onAddToPlaylist?.call();
              break;
            case 'favorite':
              onFavorite?.call();
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'play',
            child: ListTile(
              leading: Icon(Icons.play_arrow),
              title: Text('播放'),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const PopupMenuItem(
            value: 'queue',
            child: ListTile(
              leading: Icon(Icons.queue_music),
              title: Text('添加到队列'),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const PopupMenuItem(
            value: 'playlist',
            child: ListTile(
              leading: Icon(Icons.playlist_add),
              title: Text('添加到歌单'),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const PopupMenuItem(
            value: 'favorite',
            child: ListTile(
              leading: Icon(Icons.favorite_border),
              title: Text('收藏'),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}
