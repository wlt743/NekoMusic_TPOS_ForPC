import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../models/music.dart';
import '../models/playlist.dart';
import '../providers/player_provider.dart';
import '../widgets/music_list_tile.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  
  List<Music> _musicResults = [];
  List<Playlist> _playlistResults = [];
  Map<String, dynamic>? _artistResult;
  
  bool _isLoading = false;
  String? _error;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    if (query == _lastQuery) return;
    
    _lastQuery = query;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = context.read<ApiService>();
      
      final results = await Future.wait([
        apiService.searchMusic(query),
        apiService.searchPlaylists(query),
        apiService.searchArtist(query),
      ]);
      
      setState(() {
        _musicResults = results[0] as List<Music>;
        _playlistResults = results[1] as List<Playlist>;
        _artistResult = results[2] as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '搜索失败，请稍后重试';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索音乐、歌单、歌手',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _musicResults = [];
                          _playlistResults = [];
                          _artistResult = null;
                          _lastQuery = '';
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '音乐 (${_musicResults.length})'),
            Tab(text: '歌单 (${_playlistResults.length})'),
            Tab(text: '歌手'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => _search(_lastQuery),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _lastQuery.isEmpty
                  ? _buildEmptyState()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildMusicTab(),
                        _buildPlaylistTab(),
                        _buildArtistTab(),
                      ],
                    ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '搜索你喜欢的音乐',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '输入歌曲名、歌手名或歌单名',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicTab() {
    if (_musicResults.isEmpty) {
      return _buildNoResults('没有找到相关音乐');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _musicResults.length,
      itemBuilder: (context, index) {
        final music = _musicResults[index];
        return MusicListTile(
          music: music,
          index: index + 1,
          onTap: () {
            final playerProvider = context.read<PlayerProvider>();
            playerProvider.playList(_musicResults, startIndex: index);
          },
        );
      },
    );
  }

  Widget _buildPlaylistTab() {
    if (_playlistResults.isEmpty) {
      return _buildNoResults('没有找到相关歌单');
    }
    
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _playlistResults.length,
      itemBuilder: (context, index) {
        final playlist = _playlistResults[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                playlist.coverUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 56,
                  height: 56,
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.queue_music,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            title: Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${playlist.musicCount} 首歌曲',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openPlaylist(playlist),
          ),
        );
      },
    );
  }

  Widget _buildArtistTab() {
    if (_artistResult == null || _artistResult!['name'] == '') {
      return _buildNoResults('没有找到相关歌手');
    }
    
    final colorScheme = Theme.of(context).colorScheme;
    final artistName = _artistResult!['name'] as String;
    final musicCount = _artistResult!['musicCount'] as int;
    final musicList = (_artistResult!['musicList'] as List)
        .map((e) => Music.fromJson(e))
        .toList();
    
    return CustomScrollView(
      slivers: [
        // 歌手信息
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    artistName.isNotEmpty ? artistName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  artistName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$musicCount 首歌曲',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: musicList.isNotEmpty
                      ? () {
                          final playerProvider = context.read<PlayerProvider>();
                          playerProvider.playList(musicList);
                        }
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('播放全部'),
                ),
              ],
            ),
          ),
        ),
        
        // 歌曲列表
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final music = musicList[index];
              return MusicListTile(
                music: music,
                index: index + 1,
                onTap: () {
                  final playerProvider = context.read<PlayerProvider>();
                  playerProvider.playList(musicList, startIndex: index);
                },
              );
            },
            childCount: musicList.length,
          ),
        ),
        
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  Widget _buildNoResults(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPlaylist(Playlist playlist) async {
    final apiService = context.read<ApiService>();
    final playerProvider = context.read<PlayerProvider>();
    
    try {
      final musicList = await apiService.getPlaylistMusic(playlist.id);
      if (musicList.isNotEmpty) {
        playerProvider.playList(musicList);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('加载歌单失败')),
        );
      }
    }
  }
}
