import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import '../models/music.dart';
import '../services/audio_service.dart';
import '../services/api_service.dart';

class PlayerProvider extends ChangeNotifier {
  late final NekoAudioService _audioService;
  final ApiService _apiService = ApiService();

  // 歌词相关
  String? _currentLyrics;
  List<LyricLine> _parsedLyrics = [];
  int _currentLyricIndex = -1;

  // 桌面歌词显示状态
  bool _showDesktopLyrics = false;

  // 桌面歌词样式（持久化在 settings box）
  static const String _lyricColorKey = 'lyric_color';
  static const String _lyricOpacityKey = 'lyric_bg_opacity';
  static const String _lyricRadiusKey = 'lyric_radius';
  static const String _lyricFontSizeKey = 'lyric_font_size';
  static const String _lyricClickThroughKey = 'lyric_click_through';

  Color _lyricColor = const Color(0xFFFFFFFF);
  double _lyricBackgroundOpacity = 0.7;
  double _lyricCornerRadius = 16;
  double _lyricFontSize = 24;
  // 桌面歌词是否点击穿透（true=穿透不挡点击；false=可交互可拖动）
  // 默认 false：歌词作为独立可交互、可拖动的窗口（按用户需求，不再默认穿透）
  bool _lyricsClickThrough = false;

  // 收藏状态
  Set<int> _favoriteIds = {};

  PlayerProvider() {
    _audioService = NekoAudioService();
    _loadLyricStyle();
    _setupListeners();
  }

  void _loadLyricStyle() {
    try {
      final box = Hive.box('settings');
      _lyricColor = Color(box.get(_lyricColorKey, defaultValue: 0xFFFFFFFF) as int);
      _lyricBackgroundOpacity =
          (box.get(_lyricOpacityKey, defaultValue: 0.7) as num).toDouble();
      _lyricCornerRadius =
          (box.get(_lyricRadiusKey, defaultValue: 16) as num).toDouble();
      _lyricFontSize =
          (box.get(_lyricFontSizeKey, defaultValue: 24) as num).toDouble();
      _lyricsClickThrough =
          box.get(_lyricClickThroughKey, defaultValue: false) as bool;
    } catch (_) {
      // settings box 未打开时使用默认值
    }
  }
  
  // Getters
  NekoAudioService get audioService => _audioService;
  Music? get currentMusic => _audioService.currentMusic;
  List<Music> get playlist => _audioService.playlist;
  int get currentIndex => _audioService.currentIndex;
  PlayMode get playMode => _audioService.playMode;
  bool get isPlaying => _audioService.isPlaying;
  Duration get position => _audioService.position;
  Duration? get duration => _audioService.duration;
  
  String? get currentLyrics => _currentLyrics;
  List<LyricLine> get parsedLyrics => _parsedLyrics;
  int get currentLyricIndex => _currentLyricIndex;
  bool get showDesktopLyrics => _showDesktopLyrics;
  
  Set<int> get favoriteIds => _favoriteIds;
  
  // Streams
  Stream<Duration?> get positionStream => _audioService.positionStream;
  Stream<Duration?> get durationStream => _audioService.durationStream;
  Stream<PlayerState> get playerStateStream => _audioService.playerStateStream;
  Stream<bool> get playingStream => _audioService.playingStream;
  
  void _setupListeners() {
    // 监听播放位置变化，更新当前歌词
    _audioService.positionStream.listen((position) {
      if (position != null && _parsedLyrics.isNotEmpty) {
        _updateCurrentLyric(position);
      }
    });
    
    // 监听播放状态变化
    _audioService.playerStateStream.listen((state) {
      notifyListeners();
    });
  }
  
  void _updateCurrentLyric(Duration position) {
    final posMs = position.inMilliseconds;
    int newIndex = -1;
    
    for (int i = _parsedLyrics.length - 1; i >= 0; i--) {
      if (_parsedLyrics[i].timeMs <= posMs) {
        newIndex = i;
        break;
      }
    }
    
    if (newIndex != _currentLyricIndex) {
      _currentLyricIndex = newIndex;
      notifyListeners();
    }
  }

  /// 依据音频服务的实时播放位置重新计算当前歌词行。
  /// 用于在 positionStream 因失焦/切换到其他应用而暂停回调时，
  /// 由外部（如桌面歌词定时推送）主动驱动歌词滚动，避免「点击其他应用后歌词卡住」。
  void refreshCurrentLyricFromPosition() {
    if (_parsedLyrics.isEmpty) return;
    _updateCurrentLyric(_audioService.position);
  }
  
  // 播放音乐
  Future<void> play(Music music) async {
    await _audioService.play(music);
    await _loadLyrics(music.id);
    notifyListeners();
  }
  
  // 播放列表
  Future<void> playList(List<Music> list, {int startIndex = 0}) async {
    await _audioService.playList(list, startIndex: startIndex);
    if (_audioService.currentMusic != null) {
      await _loadLyrics(_audioService.currentMusic!.id);
    }
    notifyListeners();
  }
  
  // 播放/暂停
  Future<void> togglePlay() async {
    await _audioService.togglePlay();
    notifyListeners();
  }
  
  // 暂停
  Future<void> pause() async {
    await _audioService.pause();
    notifyListeners();
  }
  
  // 继续
  Future<void> resume() async {
    await _audioService.resume();
    notifyListeners();
  }
  
  // 下一首
  Future<void> playNext() async {
    await _audioService.playNext();
    if (_audioService.currentMusic != null) {
      await _loadLyrics(_audioService.currentMusic!.id);
    }
    notifyListeners();
  }
  
  // 上一首
  Future<void> playPrevious() async {
    await _audioService.playPrevious();
    if (_audioService.currentMusic != null) {
      await _loadLyrics(_audioService.currentMusic!.id);
    }
    notifyListeners();
  }
  
  // 跳转
  Future<void> seek(Duration position) async {
    await _audioService.seek(position);
  }
  
  // 切换播放模式
  void togglePlayMode() {
    _audioService.togglePlayMode();
    notifyListeners();
  }
  
  // 设置音量
  Future<void> setVolume(double volume) async {
    await _audioService.setVolume(volume);
    notifyListeners();
  }
  
  double get volume => _audioService.volume;
  
  // 添加到播放列表
  void addToPlaylist(Music music) {
    _audioService.addToPlaylist(music);
    notifyListeners();
  }
  
  // 批量添加
  void addAllToPlaylist(List<Music> musics) {
    _audioService.addAllToPlaylist(musics);
    notifyListeners();
  }
  
  // 从播放列表移除
  void removeFromPlaylist(int index) {
    _audioService.removeFromPlaylist(index);
    notifyListeners();
  }
  
  // 清空播放列表
  void clearPlaylist() {
    _audioService.clearPlaylist();
    _currentLyrics = null;
    _parsedLyrics = [];
    _currentLyricIndex = -1;
    notifyListeners();
  }
  
  // 加载歌词
  Future<void> _loadLyrics(int musicId) async {
    _currentLyrics = null;
    _parsedLyrics = [];
    _currentLyricIndex = -1;

    try {
      final lyrics = await _apiService.getLyrics(musicId);
      if (lyrics != null && _hasTimedLyrics(lyrics)) {
        _currentLyrics = lyrics;
        _parsedLyrics = _parseLyrics(lyrics);
      }
    } catch (e) {
      debugPrint('Error loading lyrics: $e');
    }

    notifyListeners();
  }

  // 判断歌词文本是否包含有效的带时间轴歌词行
  bool _hasTimedLyrics(String lyrics) {
    if (lyrics.trim().isEmpty) return false;
    final tagRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{2,3}))?\]');
    for (final line in lyrics.split('\n')) {
      final matches = tagRegex.allMatches(line);
      if (matches.isEmpty) continue;
      final text = line.replaceAll(tagRegex, '').trim();
      // 跳过元数据标签行（[ti:]/[ar:] 等不会被时间正则匹配，这里只判断时间行是否有正文）
      if (text.isNotEmpty) return true;
    }
    return false;
  }

  // 当前歌曲是否已成功加载到带时间轴的歌词
  bool get hasLyrics => _parsedLyrics.any((l) => l.text.isNotEmpty);

  // 搜索歌词：在曲库中按关键词查找候选歌曲（其歌词可被借用）
  Future<List<Music>> searchLyrics(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      return await _apiService.searchMusic(query);
    } catch (e) {
      debugPrint('Error searching lyrics: $e');
      return [];
    }
  }

  // 应用指定歌曲的歌词到当前播放（手动匹配歌词）
  Future<bool> applyLyricsFromMusic(int musicId) async {
    try {
      final lyrics = await _apiService.getLyrics(musicId);
      if (lyrics != null && _hasTimedLyrics(lyrics)) {
        _currentLyrics = lyrics;
        _parsedLyrics = _parseLyrics(lyrics);
        _currentLyricIndex = -1;
        _updateCurrentLyric(_audioService.position);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error applying lyrics: $e');
    }
    return false;
  }

  // 直接应用一段 LRC 文本作为当前歌词
  bool applyLyricsText(String lyrics) {
    if (!_hasTimedLyrics(lyrics)) return false;
    _currentLyrics = lyrics;
    _parsedLyrics = _parseLyrics(lyrics);
    _currentLyricIndex = -1;
    _updateCurrentLyric(_audioService.position);
    notifyListeners();
    return true;
  }
  
  // 解析歌词
  //
  // 兼容多种 LRC 时间标签格式：
  //  - [mm:ss.xxx] / [mm:ss.xx]（带毫秒，2~3 位）
  //  - [mm:ss]（不带毫秒）
  //  - [m:ss]（分钟为单数位）
  //  - 同一行多个时间标签，如 [00:01.00][00:30.00]歌词
  // 并自动忽略元数据标签（[ti:]、[ar:]、[by:] 等）。
  List<LyricLine> _parseLyrics(String lyrics) {
    final lines = <LyricLine>[];
    // 单个时间标签：分钟 1+ 位，秒 2 位，毫秒可选（. 或 : 分隔，2~3 位）
    final tagRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{2,3}))?\]');

    for (final rawLine in lyrics.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final matches = tagRegex.allMatches(line).toList();
      if (matches.isEmpty) continue;

      // 去掉本行所有时间标签后剩下的即为歌词文本
      final text = line.replaceAll(tagRegex, '').trim();

      for (final match in matches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millisStr = match.group(3);
        final millis = millisStr != null
            ? int.parse(millisStr.padRight(3, '0').substring(0, 3))
            : 0;

        final timeMs = minutes * 60 * 1000 + seconds * 1000 + millis;
        // 允许空文本行（用于段落间隔），仍保留时间点
        lines.add(LyricLine(timeMs: timeMs, text: text));
      }
    }

    lines.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return lines;
  }
  
  // 获取当前歌词文本
  String get currentLyricText {
    if (_currentLyricIndex >= 0 && _currentLyricIndex < _parsedLyrics.length) {
      return _parsedLyrics[_currentLyricIndex].text;
    }
    return '';
  }
  
  // 获取下一行歌词文本
  String get nextLyricText {
    final nextIndex = _currentLyricIndex + 1;
    if (nextIndex >= 0 && nextIndex < _parsedLyrics.length) {
      return _parsedLyrics[nextIndex].text;
    }
    return '';
  }

  /// 当前歌词行的播放进度（0.0~1.0）。
  /// 对应 PC 端桌面歌词胶囊底部的进度条：当前行已唱时长 / 当前行总时长。
  double get currentLineProgress {
    if (_currentLyricIndex < 0 || _currentLyricIndex >= _parsedLyrics.length) {
      return 0.0;
    }
    final curTime = _parsedLyrics[_currentLyricIndex].timeMs;
    final nextIndex = _currentLyricIndex + 1;
    if (nextIndex >= _parsedLyrics.length) {
      // 最后一行：用歌曲总时长作为终点
      final total = _audioService.duration?.inMilliseconds ?? 0;
      if (total <= curTime) return 0.0;
      final pos = _audioService.position.inMilliseconds;
      return ((pos - curTime) / (total - curTime)).clamp(0.0, 1.0);
    }
    final nextTime = _parsedLyrics[nextIndex].timeMs;
    if (nextTime <= curTime) return 0.0;
    final pos = _audioService.position.inMilliseconds;
    return ((pos - curTime) / (nextTime - curTime)).clamp(0.0, 1.0);
  }
  
  // 切换桌面歌词显示
  void toggleDesktopLyrics() {
    _showDesktopLyrics = !_showDesktopLyrics;
    notifyListeners();
  }
  
  void setShowDesktopLyrics(bool show) {
    _showDesktopLyrics = show;
    notifyListeners();
  }

  // ==================== 桌面歌词样式 ====================
  Color get lyricColor => _lyricColor;
  double get lyricBackgroundOpacity => _lyricBackgroundOpacity;
  double get lyricCornerRadius => _lyricCornerRadius;
  double get lyricFontSize => _lyricFontSize;

  void _putSetting(String key, dynamic value) {
    try {
      Hive.box('settings').put(key, value);
    } catch (_) {}
  }

  void setLyricColor(Color color) {
    _lyricColor = color;
    _putSetting(_lyricColorKey, color.value);
    notifyListeners();
  }

  void setLyricBackgroundOpacity(double opacity) {
    _lyricBackgroundOpacity = opacity.clamp(0.0, 1.0);
    _putSetting(_lyricOpacityKey, _lyricBackgroundOpacity);
    notifyListeners();
  }

  void setLyricCornerRadius(double radius) {
    _lyricCornerRadius = radius.clamp(0.0, 40.0);
    _putSetting(_lyricRadiusKey, _lyricCornerRadius);
    notifyListeners();
  }

  void setLyricFontSize(double size) {
    _lyricFontSize = size.clamp(12.0, 48.0);
    _putSetting(_lyricFontSizeKey, _lyricFontSize);
    notifyListeners();
  }

  bool get lyricsClickThrough => _lyricsClickThrough;

  void setLyricsClickThrough(bool value) {
    _lyricsClickThrough = value;
    _putSetting(_lyricClickThroughKey, value);
    notifyListeners();
  }

  void toggleLyricsClickThrough() {
    setLyricsClickThrough(!_lyricsClickThrough);
  }

  // 收藏相关
  void setFavorites(Set<int> ids) {
    _favoriteIds = ids;
    notifyListeners();
  }
  
  void addFavorite(int id) {
    _favoriteIds.add(id);
    notifyListeners();
  }
  
  void removeFavorite(int id) {
    _favoriteIds.remove(id);
    notifyListeners();
  }
  
  bool isFavorite(int id) => _favoriteIds.contains(id);
  
  // 获取播放模式图标
  IconData get playModeIcon {
    switch (playMode) {
      case PlayMode.sequence:
        return Icons.repeat;
      case PlayMode.loop:
        return Icons.repeat_on;
      case PlayMode.single:
        return Icons.repeat_one;
      case PlayMode.shuffle:
        return Icons.shuffle;
    }
  }
  
  // 获取播放模式名称
  String get playModeName {
    switch (playMode) {
      case PlayMode.sequence:
        return '顺序播放';
      case PlayMode.loop:
        return '列表循环';
      case PlayMode.single:
        return '单曲循环';
      case PlayMode.shuffle:
        return '随机播放';
    }
  }
  
  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}

// 歌词行
class LyricLine {
  final int timeMs;
  final String text;
  
  LyricLine({required this.timeMs, required this.text});
}
