import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import '../providers/player_provider.dart';
import '../providers/user_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../models/music.dart';
import '../widgets/player_bar.dart';
import '../widgets/desktop_lyrics_overlay.dart';
import 'discover_page.dart';
import 'search_page.dart';
import 'library_page.dart';
import 'profile_page.dart';
import 'now_playing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = const [
    DiscoverPage(),
    SearchPage(),
    LibraryPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    final userProvider = context.read<UserProvider>();
    final apiService = context.read<ApiService>();
    userProvider.restoreToken(apiService);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        return Stack(
          children: [
            Scaffold(
              body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
            ),
            // 桌面歌词悬浮窗（仅桌面平台）
            if (isDesktop && playerProvider.showDesktopLyrics)
              const DesktopLyricsOverlay(),
          ],
        );
      },
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
        ),
        const PlayerBar(),
        NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: '发现',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search),
              label: '搜索',
            ),
            NavigationDestination(
              icon: Icon(Icons.library_music_outlined),
              selectedIcon: Icon(Icons.library_music),
              label: '音乐库',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      children: [
        // 侧边导航栏
        Container(
          width: 220,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            border: Border(
              right: BorderSide(
                color: colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
          ),
          child: Column(
            children: [
              // macOS 窗口拖拽区域
              if (Platform.isMacOS)
                const SizedBox(height: 28),
              
              // Logo
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.tertiary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Neko云音乐',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // 导航项
              _buildNavItem(0, Icons.explore_outlined, Icons.explore, '发现'),
              _buildNavItem(1, Icons.search_outlined, Icons.search, '搜索'),
              _buildNavItem(2, Icons.library_music_outlined, Icons.library_music, '音乐库'),
              _buildNavItem(3, Icons.person_outline, Icons.person, '我的'),
              
              const Spacer(),
              
              // 底部播放器小部件
              const DesktopMiniPlayer(),
            ],
          ),
        ),
        
        // 主内容区
        Expanded(
          child: Column(
            children: [
              // macOS 窗口拖拽区域
              if (Platform.isMacOS)
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  child: Container(
                    height: 28,
                    color: Colors.transparent,
                  ),
                ),
              
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _pages,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData selectedIcon, String label) {
    final isSelected = _currentIndex == index;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            setState(() {
              _currentIndex = index;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: 22,
                  color: isSelected 
                      ? colorScheme.onPrimaryContainer 
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected 
                        ? colorScheme.onPrimaryContainer 
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 桌面端迷你播放器
class DesktopMiniPlayer extends StatelessWidget {
  const DesktopMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        final music = playerProvider.currentMusic;
        
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
          ),
          child: Column(
            children: [
              // 歌曲信息
              if (music != null)
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NowPlayingScreen(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      // 封面
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          music.coverUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 48,
                            height: 48,
                            color: colorScheme.primaryContainer,
                            child: Icon(
                              Icons.music_note,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              music.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              music.artist,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.music_note,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '未在播放',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              
              const SizedBox(height: 12),
              
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
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(2),
                  );
                },
              ),
              
              const SizedBox(height: 8),
              
              // 控制按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: playerProvider.playPrevious,
                    icon: const Icon(Icons.skip_previous, size: 22),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    onPressed: playerProvider.togglePlay,
                    icon: Icon(
                      playerProvider.isPlaying 
                          ? Icons.pause_circle_filled 
                          : Icons.play_circle_filled,
                      size: 32,
                    ),
                    color: colorScheme.primary,
                  ),
                  IconButton(
                    onPressed: playerProvider.playNext,
                    icon: const Icon(Icons.skip_next, size: 22),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              // 桌面歌词开关
              TextButton.icon(
                onPressed: playerProvider.toggleDesktopLyrics,
                icon: Icon(
                  playerProvider.showDesktopLyrics 
                      ? Icons.lyrics 
                      : Icons.lyrics_outlined,
                  size: 16,
                ),
                label: Text(
                  playerProvider.showDesktopLyrics ? '关闭桌面歌词' : '桌面歌词',
                  style: const TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
