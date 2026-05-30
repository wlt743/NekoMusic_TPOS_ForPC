import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

import '../providers/theme_provider.dart';
import '../providers/player_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();
    final playerProvider = context.watch<PlayerProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // 外观设置
          _buildSectionHeader('外观'),
          ListTile(
            leading: Icon(themeProvider.themeModeIcon),
            title: const Text('主题模式'),
            subtitle: Text(themeProvider.themeModeName),
            onTap: () => _showThemeModeSheet(context, themeProvider),
          ),
          ListTile(
            leading: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: themeProvider.primaryColor,
                shape: BoxShape.circle,
              ),
            ),
            title: const Text('主题色'),
            subtitle: const Text('自定义应用主色调'),
            onTap: () => _showColorPickerSheet(context, themeProvider),
          ),
          const Divider(),
          
          // 播放设置
          _buildSectionHeader('播放'),
          ListTile(
            leading: Icon(playerProvider.playModeIcon),
            title: const Text('默认播放模式'),
            subtitle: Text(playerProvider.playModeName),
            onTap: () => _showPlayModeSheet(context, playerProvider),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lyrics),
            title: const Text('桌面歌词'),
            subtitle: const Text('在屏幕上显示浮动歌词'),
            value: playerProvider.showDesktopLyrics,
            onChanged: (value) {
              playerProvider.setShowDesktopLyrics(value);
            },
          ),
          const Divider(),
          
          // 缓存设置
          _buildSectionHeader('存储'),
          ListTile(
            leading: const Icon(Icons.cleaning_services),
            title: const Text('清除缓存'),
            subtitle: const Text('清除图片和临时文件缓存'),
            onTap: () => _clearCache(context),
          ),
          const Divider(),
          
          // 关于
          _buildSectionHeader('关于'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('开源协议'),
            subtitle: const Text('AGPL-3.0 License'),
            onTap: () => _showLicenseDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.public),
            title: const Text('API 文档'),
            subtitle: const Text('https://github.com/FantasyNetworkCN/NekoMusicDocs'),
            onTap: () {
              // TODO: 打开链接
            },
          ),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showThemeModeSheet(BuildContext context, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '选择主题模式',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: const Text('跟随系统'),
              trailing: themeProvider.themeMode == ThemeMode.system
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.system);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: const Text('浅色模式'),
              trailing: themeProvider.themeMode == ThemeMode.light
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('深色模式'),
              trailing: themeProvider.themeMode == ThemeMode.dark
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showColorPickerSheet(BuildContext context, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '选择主题色',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: ThemeProvider.presetColors.map((color) {
                  final isSelected = themeProvider.primaryColor.value == color.value;
                  return GestureDetector(
                    onTap: () {
                      themeProvider.setPrimaryColor(color);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.5),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 28)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlayModeSheet(BuildContext context, PlayerProvider playerProvider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '选择播放模式',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.repeat),
              title: const Text('顺序播放'),
              onTap: () {
                // 设置播放模式
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.repeat_on),
              title: const Text('列表循环'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.repeat_one),
              title: const Text('单曲循环'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shuffle),
              title: const Text('随机播放'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _clearCache(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有缓存数据吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        final cacheBox = Hive.box('cache');
        await cacheBox.clear();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('缓存已清除')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('清除缓存失败')),
          );
        }
      }
    }
  }

  void _showLicenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('开源协议'),
        content: const SingleChildScrollView(
          child: Text('''
GNU Affero General Public License v3.0 (AGPL-3.0)

Copyright (C) 2024 Neko云音乐

本程序是自由软件：你可以遵照自由软件基金会发布的 GNU Affero 通用公共许可证（AGPL）第 3 版或（由你选择）任何后续版本的条款，重新发布和/或修改它。

发布本程序是希望它能有用，但不附带任何担保；甚至不包含适销性或针对特定用途的适用性的默示担保。详见 GNU Affero 通用公共许可证。

特别地，根据 AGPL 第 13 条：如果你修改本程序并通过计算机网络向用户提供交互式服务，你必须向这些用户提供获取对应修改后源代码的途径。

你应当已随本程序收到一份 GNU Affero 通用公共许可证的副本。如果没有，请参阅 <https://www.gnu.org/licenses/>。

---

本项目基于 Neko云音乐 API 开发，依据其 API 文档规定采用 AGPL-3.0 协议开源。
API 文档: https://github.com/FantasyNetworkCN/NekoMusicDocs
源码地址: https://github.com/bilibilicraft/NekoMusicAndroid_Macos
          '''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
