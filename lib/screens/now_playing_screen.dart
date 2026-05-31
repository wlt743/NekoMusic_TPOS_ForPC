import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

import '../models/music.dart';
import '../providers/player_provider.dart';

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
        
        // macOS 隐藏了原生标题栏，红绿灯位于左上角顶部约 28px 区域，
        // 需把工具栏整体下移，避免返回按钮与红绿灯重合/误触
        final isMacOS = Platform.isMacOS;
        const macTrafficLightHeight = 28.0;
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(
              isMacOS ? kToolbarHeight + macTrafficLightHeight : kToolbarHeight,
            ),
            child: Padding(
              // 顶部留出红绿灯高度，使整条工具栏下移到红绿灯之下
              padding: EdgeInsets.only(top: isMacOS ? macTrafficLightHeight : 0),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 32),
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
            ),
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
              leading: const Icon(Icons.lyrics_outlined),
              title: const Text('搜索歌词'),
              subtitle: const Text('当前歌曲无歌词时手动匹配'),
              onTap: () {
                Navigator.pop(context);
                _showLyricSearchSheet(context, playerProvider);
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
              leading: const Icon(Icons.palette_outlined),
              title: const Text('桌面歌词样式'),
              subtitle: const Text('颜色、透明度、圆角、字号'),
              onTap: () {
                Navigator.pop(context);
                _showLyricStyleSheet(context, playerProvider);
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

  // 搜索歌词：手动在曲库中找匹配歌词的歌曲并套用其歌词
  void _showLyricSearchSheet(BuildContext context, PlayerProvider playerProvider) {
    final searchController = TextEditingController(
      text: playerProvider.currentMusic != null
          ? '${playerProvider.currentMusic!.title} ${playerProvider.currentMusic!.artist}'
          : '',
    );
    final results = <Music>[];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> doSearch() async {
              final query = searchController.text.trim();
              if (query.isEmpty) return;
              setSheetState(() => isSearching = true);
              final found = await playerProvider.searchLyrics(query);
              setSheetState(() {
                results
                  ..clear()
                  ..addAll(found);
                isSearching = false;
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.7,
                maxChildSize: 0.95,
                minChildSize: 0.4,
                expand: false,
                builder: (context, scrollController) {
                  return Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          '搜索歌词',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: searchController,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  hintText: '输入歌名 / 歌手',
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onSubmitted: (_) => doSearch(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: isSearching ? null : doSearch,
                              child: const Text('搜索'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: isSearching
                            ? const Center(child: CircularProgressIndicator())
                            : results.isEmpty
                                ? const Center(
                                    child: Text('输入关键词后点击搜索'),
                                  )
                                : ListView.builder(
                                    controller: scrollController,
                                    itemCount: results.length,
                                    itemBuilder: (context, index) {
                                      final m = results[index];
                                      return ListTile(
                                        leading: const Icon(Icons.lyrics_outlined),
                                        title: Text(
                                          m.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          m.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: const Icon(Icons.check_circle_outline),
                                        onTap: () async {
                                          final ok = await playerProvider
                                              .applyLyricsFromMusic(m.id);
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(ok ? '已应用歌词' : '该歌曲没有可用歌词'),
                                                duration: const Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                      );
                                    },
                                  ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // 桌面歌词样式：颜色、透明度、圆角、字号
  void _showLyricStyleSheet(BuildContext context, PlayerProvider playerProvider) {
    final colors = <Color>[
      Colors.white,
      const Color(0xFFFF6B9D),
      const Color(0xFF6C5CE7),
      const Color(0xFF00B894),
      const Color(0xFF0984E3),
      const Color(0xFFFDCB6E),
      const Color(0xFFE17055),
      const Color(0xFF00CEC9),
      Colors.black,
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          '桌面歌词样式',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black
                              .withOpacity(playerProvider.lyricBackgroundOpacity),
                          borderRadius: BorderRadius.circular(
                            playerProvider.lyricCornerRadius,
                          ),
                        ),
                        child: Text(
                          '歌词预览 ♪',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: playerProvider.lyricColor,
                            fontSize: playerProvider.lyricFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('文字颜色',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: colors.map((color) {
                          final isSelected =
                              playerProvider.lyricColor.value == color.value;
                          return GestureDetector(
                            onTap: () {
                              playerProvider.setLyricColor(color);
                              setSheetState(() {});
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.withOpacity(0.4),
                                  width: isSelected ? 3 : 1,
                                ),
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      size: 20,
                                      color: color == Colors.white
                                          ? Colors.black
                                          : Colors.white,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Text('背景透明度',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text(
                            '${(playerProvider.lyricBackgroundOpacity * 100).round()}%',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: playerProvider.lyricBackgroundOpacity,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        onChanged: (value) {
                          playerProvider.setLyricBackgroundOpacity(value);
                          setSheetState(() {});
                        },
                      ),
                      Row(
                        children: [
                          const Text('圆角',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text(
                            '${playerProvider.lyricCornerRadius.round()}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: playerProvider.lyricCornerRadius,
                        min: 0.0,
                        max: 40.0,
                        divisions: 40,
                        onChanged: (value) {
                          playerProvider.setLyricCornerRadius(value);
                          setSheetState(() {});
                        },
                      ),
                      Row(
                        children: [
                          const Text('字号',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text(
                            '${playerProvider.lyricFontSize.round()}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: playerProvider.lyricFontSize,
                        min: 12.0,
                        max: 48.0,
                        divisions: 36,
                        onChanged: (value) {
                          playerProvider.setLyricFontSize(value);
                          setSheetState(() {});
                        },
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            playerProvider.setLyricColor(Colors.white);
                            playerProvider.setLyricBackgroundOpacity(0.7);
                            playerProvider.setLyricCornerRadius(16);
                            playerProvider.setLyricFontSize(24);
                            setSheetState(() {});
                          },
                          child: const Text('恢复默认'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
