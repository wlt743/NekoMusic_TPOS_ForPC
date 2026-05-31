import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import '../providers/player_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/lyrics_window_manager.dart';
import '../widgets/player_bar.dart';
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

  // 独立桌面歌词窗口管理（仅桌面平台）
  LyricsWindowManager? _lyricsWindowManager;
  PlayerProvider? _player;
  bool _lastShowLyrics = false;
  
  final List<Widget> _pages = const [
    DiscoverPage(),
    SearchPage(),
    LibraryPage(),
    ProfilePage(),
  ];

  bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    _initializeUser();

    // 桌面平台：监听桌面歌词开关，控制独立歌词窗口
    if (_isDesktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _player = context.read<PlayerProvider>();
        _lyricsWindowManager = LyricsWindowManager(_player!);
        _lastShowLyrics = _player!.showDesktopLyrics;
        _player!.addListener(_syncLyricsWindow);
        if (_lastShowLyrics) {
          _lyricsWindowManager!.open();
        }
      });
    }
  }

  void _syncLyricsWindow() {
    final player = _player;
    final manager = _lyricsWindowManager;
    if (player == null || manager == null) return;
    final show = player.showDesktopLyrics;
    if (show == _lastShowLyrics) return;
    _lastShowLyrics = show;
    if (show) {
      manager.open();
    } else {
      manager.close();
    }
  }

  @override
  void dispose() {
    _player?.removeListener(_syncLyricsWindow);
    _lyricsWindowManager?.close();
    super.dispose();
  }

  Future<void> _initializeUser() async {
    final userProvider = context.read<UserProvider>();
    final apiService = context.read<ApiService>();
    userProvider.restoreToken(apiService);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
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
              
              // 桌面歌词开关 + 样式入口
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: TextButton.icon(
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
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        _showDesktopLyricStyleSheet(context, playerProvider),
                    icon: const Icon(Icons.palette_outlined, size: 18),
                    tooltip: '桌面歌词样式',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    onPressed: playerProvider.toggleLyricsClickThrough,
                    icon: Icon(
                      playerProvider.lyricsClickThrough
                          ? Icons.touch_app_outlined
                          : Icons.pan_tool,
                      size: 18,
                    ),
                    tooltip: playerProvider.lyricsClickThrough
                        ? '歌词穿透中(点击可拖动)'
                        : '歌词可拖动(点击恢复穿透)',
                    color: playerProvider.lyricsClickThrough
                        ? null
                        : Theme.of(context).colorScheme.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// 桌面歌词样式调节面板（颜色、透明度、圆角、字号）
void _showDesktopLyricStyleSheet(
    BuildContext context, PlayerProvider playerProvider) {
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
