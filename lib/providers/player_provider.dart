import 'package:flutter/material.dart';
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
  
  // 收藏状态
  Set<int> _favoriteIds = {};
  
  PlayerProvider() {
    _audioService = NekoAudioService();
    _setupListeners();
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
      if (lyrics != null && lyrics.isNotEmpty) {
        _currentLyrics = lyrics;
        _parsedLyrics = _parseLyrics(lyrics);
      }
    } catch (e) {
      print('Error loading lyrics: $e');
    }
    
    notifyListeners();
  }
  
  // 解析歌词
  List<LyricLine> _parseLyrics(String lyrics) {
    final lines = <LyricLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
    
    for (final line in lyrics.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millisStr = match.group(3)!;
        final millis = int.parse(millisStr.padRight(3, '0'));
        final text = match.group(4)?.trim() ?? '';
        
        final timeMs = minutes * 60 * 1000 + seconds * 1000 + millis;
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
  
  // 切换桌面歌词显示
  void toggleDesktopLyrics() {
    _showDesktopLyrics = !_showDesktopLyrics;
    notifyListeners();
  }
  
  void setShowDesktopLyrics(bool show) {
    _showDesktopLyrics = show;
    notifyListeners();
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
