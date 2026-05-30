import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../models/music.dart';
import '../models/playlist.dart';
import '../providers/player_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/music_list_tile.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<Music> _favorites = [];
  List<Playlist> _playlists = [];
  List<Music> _currentPlaylist = [];
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final userProvider = context.read<UserProvider>();
    if (!userProvider.isLoggedIn) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = context.read<ApiService>();
      
      final results = await Future.wait([
        apiService.getFavorites(),
        apiService.getMyPlaylists(),
      ]);
      
      setState(() {
        _favorites = results[0] as List<Music>;
        _playlists = results[1] as List<Playlist>;
        _isLoading = false;
      });
      
      // 更新收藏状态
      final playerProvider = context.read<PlayerProvider>();
      playerProvider.setFavorites(_favorites.map((m) => m.id).toSet());
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final userProvider = context.watch<UserProvider>();
    final playerProvider = context.watch<PlayerProvider>();
    
    if (!userProvider.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('音乐库')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.library_music,
                size: 80,
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                '登录后查看你的音乐库',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  // 跳转到个人页面登录
                },
                child: const Text('去登录'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('音乐库'),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '收藏 (${_favorites.length})'),
            Tab(text: '歌单 (${_playlists.length})'),
            Tab(text: '播放队列 (${playerProvider.playlist.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFavoritesTab(),
                _buildPlaylistsTab(),
                _buildQueueTab(),
              ],
            ),
    );
  }

  Widget _buildFavoritesTab() {
    if (_favorites.isEmpty) {
      return _buildEmptyState(
        icon: Icons.favorite_border,
        title: '还没有收藏的歌曲',
        subtitle: '点击歌曲旁的爱心收藏你喜欢的音乐',
      );
    }
    
    return Column(
      children: [
        // 播放全部按钮
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: () {
                  final playerProvider = context.read<PlayerProvider>();
                  playerProvider.playList(_favorites);
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('播放全部'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  final playerProvider = context.read<PlayerProvider>();
                  final shuffled = List<Music>.from(_favorites)..shuffle();
                  playerProvider.playList(shuffled);
                },
                icon: const Icon(Icons.shuffle),
                label: const Text('随机播放'),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: _favorites.length,
              itemBuilder: (context, index) {
                final music = _favorites[index];
                return MusicListTile(
                  music: music,
                  index: index + 1,
                  showFavorite: true,
                  onTap: () {
                    final playerProvider = context.read<PlayerProvider>();
                    playerProvider.playList(_favorites, startIndex: index);
                  },
                  onFavoriteToggle: () => _toggleFavorite(music),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistsTab() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      children: [
        // 创建歌单按钮
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showCreatePlaylistDialog,
              icon: const Icon(Icons.add),
              label: const Text('创建歌单'),
            ),
          ),
        ),
        
        Expanded(
          child: _playlists.isEmpty
              ? _buildEmptyState(
                  icon: Icons.queue_music,
                  title: '还没有创建歌单',
                  subtitle: '点击上方按钮创建你的第一个歌单',
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: _playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = _playlists[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'play',
                                child: ListTile(
                                  leading: Icon(Icons.play_arrow),
                                  title: Text('播放'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit),
                                  title: Text('编辑'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(Icons.delete),
                                  title: Text('删除'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              switch (value) {
                                case 'play':
                                  _playPlaylist(playlist);
                                  break;
                                case 'edit':
                                  _showEditPlaylistDialog(playlist);
                                  break;
                                case 'delete':
                                  _deletePlaylist(playlist);
                                  break;
                              }
                            },
                          ),
                          onTap: () => _playPlaylist(playlist),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildQueueTab() {
    final playerProvider = context.watch<PlayerProvider>();
    final queue = playerProvider.playlist;
    final currentIndex = playerProvider.currentIndex;
    
    if (queue.isEmpty) {
      return _buildEmptyState(
        icon: Icons.queue_music,
        title: '播放队列为空',
        subtitle: '播放音乐后会显示在这里',
      );
    }
    
    return Column(
      children: [
        // 清空队列按钮
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                '当前播放: ${currentIndex + 1}/${queue.length}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  playerProvider.clearPlaylist();
                },
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('清空'),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: queue.length,
            onReorder: (oldIndex, newIndex) {
              // TODO: 实现拖拽排序
            },
            itemBuilder: (context, index) {
              final music = queue[index];
              final isPlaying = index == currentIndex;
              
              return MusicListTile(
                key: ValueKey(music.id),
                music: music,
                index: index + 1,
                isPlaying: isPlaying,
                onTap: () {
                  playerProvider.playList(queue, startIndex: index);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    playerProvider.removeFromPlaylist(index);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 80,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(Music music) async {
    final apiService = context.read<ApiService>();
    final playerProvider = context.read<PlayerProvider>();
    
    try {
      if (playerProvider.isFavorite(music.id)) {
        await apiService.removeFavorite(music.id);
        playerProvider.removeFavorite(music.id);
        setState(() {
          _favorites.removeWhere((m) => m.id == music.id);
        });
      } else {
        await apiService.addFavorite(music.id);
        playerProvider.addFavorite(music.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作失败')),
        );
      }
    }
  }

  Future<void> _playPlaylist(Playlist playlist) async {
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

  Future<void> _showCreatePlaylistDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建歌单'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '歌单名称',
                hintText: '输入歌单名称',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: '描述 (可选)',
                hintText: '输入歌单描述',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    
    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        final apiService = context.read<ApiService>();
        final playlist = await apiService.createPlaylist(
          nameController.text.trim(),
          description: descController.text.trim(),
        );
        if (playlist != null) {
          _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('歌单创建成功')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('创建失败')),
          );
        }
      }
    }
  }

  Future<void> _showEditPlaylistDialog(Playlist playlist) async {
    final nameController = TextEditingController(text: playlist.name);
    final descController = TextEditingController(text: playlist.description ?? '');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑歌单'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '歌单名称',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: '描述 (可选)',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    
    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        final apiService = context.read<ApiService>();
        await apiService.updatePlaylist(
          playlist.id,
          nameController.text.trim(),
          description: descController.text.trim(),
        );
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('更新失败')),
          );
        }
      }
    }
  }

  Future<void> _deletePlaylist(Playlist playlist) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除歌单'),
        content: Text('确定要删除歌单"${playlist.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        final apiService = context.read<ApiService>();
        await apiService.deletePlaylist(playlist.id);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('歌单已删除')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除失败')),
          );
        }
      }
    }
  }
}
