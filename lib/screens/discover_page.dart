import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/api_service.dart';
import '../models/music.dart';
import '../providers/player_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/music_list_tile.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  List<Music> _ranking = [];
  List<Music> _latest = [];
  List<Music> _dailyRecommendations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = context.read<ApiService>();
      final userProvider = context.read<UserProvider>();
      
      final results = await Future.wait([
        apiService.getRanking(limit: 50),
        apiService.getLatestMusic(limit: 50),
      ]);

      // 仅登录用户加载每日推荐，失败不影响其他内容
      List<Music> daily = [];
      if (userProvider.isLoggedIn) {
        try {
          daily = await apiService.getDailyRecommendations();
        } catch (_) {
          daily = [];
        }
      }
      
      setState(() {
        _ranking = results[0];
        _latest = results[1];
        _dailyRecommendations = daily;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败，请稍后重试';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // 顶部 AppBar
            SliverAppBar(
              floating: true,
              title: const Text('发现音乐'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: IconButton(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    tooltip: '刷新',
                  ),
                ),
              ],
            ),
            
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadData,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // 每日推荐（仅登录且有数据时显示）
              if (_dailyRecommendations.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '每日推荐',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _playAll(_dailyRecommendations),
                          child: const Text('播放全部'),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 226,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _dailyRecommendations.length,
                      itemBuilder: (context, index) {
                        final music = _dailyRecommendations[index];
                        return _buildRecommendationCard(music, index);
                      },
                    ),
                  ),
                ),
              ],

              // 热门歌曲标题
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '热门歌曲',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _playAll(_ranking),
                        child: const Text('播放全部'),
                      ),
                    ],
                  ),
                ),
              ),
              
              // 热门歌曲横向列表
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _ranking.take(10).length,
                    itemBuilder: (context, index) {
                      final music = _ranking[index];
                      return _buildMusicCard(music, index + 1);
                    },
                  ),
                ),
              ),
              
              // 最新上传标题
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.new_releases,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '最新上传',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _playAll(_latest),
                        child: const Text('播放全部'),
                      ),
                    ],
                  ),
                ),
              ),
              
              // 最新上传列表
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final music = _latest[index];
                    return MusicListTile(
                      music: music,
                      index: index + 1,
                      onTap: () => _playMusic(music, _latest, index),
                    );
                  },
                  childCount: _latest.take(20).length,
                ),
              ),
              
              // 底部安全区域
              const SliverPadding(
                padding: EdgeInsets.only(bottom: 100),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMusicCard(Music music, int rank) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: () => _playMusic(music, _ranking, rank - 1),
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: music.coverUrl,
                    width: 150,
                    height: 150,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 150,
                      height: 150,
                      color: colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 150,
                      height: 150,
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.music_note,
                        size: 48,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                // 排名标签
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: rank <= 3 
                          ? colorScheme.error 
                          : colorScheme.surfaceContainerHighest.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: rank <= 3 
                            ? colorScheme.onError 
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                // 播放图标
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      color: colorScheme.onPrimary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 标题
            Text(
              music.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            // 歌手
            Text(
              music.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(Music music, int index) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _playMusic(music, _dailyRecommendations, index),
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: music.coverUrl,
                    width: 150,
                    height: 150,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 150,
                      height: 150,
                      color: colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 150,
                      height: 150,
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.music_note,
                        size: 48,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                // AI 推荐标签
                if (music.source != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            music.source == 'ai'
                                ? Icons.auto_awesome
                                : Icons.tune,
                            size: 12,
                            color: colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            music.source == 'ai' ? 'AI' : '推荐',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      color: colorScheme.onPrimary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              music.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              music.reason ?? music.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playMusic(Music music, List<Music> list, int index) {
    final playerProvider = context.read<PlayerProvider>();
    playerProvider.playList(list, startIndex: index);
  }

  void _playAll(List<Music> list) {
    if (list.isEmpty) return;
    final playerProvider = context.read<PlayerProvider>();
    playerProvider.playList(list);
  }
}
