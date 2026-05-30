import 'package:just_audio/just_audio.dart';
import '../models/music.dart';
import 'api_service.dart';

enum PlayMode {
  sequence, // 顺序播放
  loop,     // 列表循环
  single,   // 单曲循环
  shuffle,  // 随机播放
}

class NekoAudioService {
  final AudioPlayer _player = AudioPlayer();
  
  List<Music> _playlist = [];
  int _currentIndex = -1;
  PlayMode _playMode = PlayMode.sequence;
  
  // Getters
  AudioPlayer get player => _player;
  List<Music> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  Music? get currentMusic => _currentIndex >= 0 && _currentIndex < _playlist.length
      ? _playlist[_currentIndex]
      : null;
  PlayMode get playMode => _playMode;
  
  // Streams
  Stream<Duration?> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<bool> get playingStream => _player.playingStream;
  
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  
  NekoAudioService() {
    _setupPlayerListeners();
  }
  
  void _setupPlayerListeners() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onTrackComplete();
      }
    });
  }
  
  void _onTrackComplete() {
    switch (_playMode) {
      case PlayMode.single:
        _player.seek(Duration.zero);
        _player.play();
        break;
      case PlayMode.sequence:
        if (_currentIndex < _playlist.length - 1) {
          playNext();
        }
        break;
      case PlayMode.loop:
      case PlayMode.shuffle:
        playNext();
        break;
    }
  }
  
  // 播放指定音乐
  Future<void> play(Music music) async {
    final index = _playlist.indexWhere((m) => m.id == music.id);
    if (index >= 0) {
      await playAt(index);
    } else {
      _playlist = [music];
      _currentIndex = 0;
      await _loadAndPlay();
    }
  }
  
  // 播放列表中指定位置的音乐
  Future<void> playAt(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;
    await _loadAndPlay();
  }
  
  // 设置播放列表并播放
  Future<void> playList(List<Music> list, {int startIndex = 0}) async {
    if (list.isEmpty) return;
    _playlist = List.from(list);
    _currentIndex = startIndex.clamp(0, list.length - 1);
    await _loadAndPlay();
  }
  
  // 添加到播放列表
  void addToPlaylist(Music music) {
    if (!_playlist.any((m) => m.id == music.id)) {
      _playlist.add(music);
    }
  }
  
  // 添加多首到播放列表
  void addAllToPlaylist(List<Music> musics) {
    for (final music in musics) {
      if (!_playlist.any((m) => m.id == music.id)) {
        _playlist.add(music);
      }
    }
  }
  
  // 从播放列表移除
  void removeFromPlaylist(int index) {
    if (index < 0 || index >= _playlist.length) return;
    
    _playlist.removeAt(index);
    
    if (_playlist.isEmpty) {
      _currentIndex = -1;
      _player.stop();
    } else if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      if (_currentIndex >= _playlist.length) {
        _currentIndex = _playlist.length - 1;
      }
      _loadAndPlay();
    }
  }
  
  // 清空播放列表
  void clearPlaylist() {
    _playlist.clear();
    _currentIndex = -1;
    _player.stop();
  }
  
  Future<void> _loadAndPlay() async {
    final music = currentMusic;
    if (music == null) return;
    
    try {
      final url = ApiService.getMusicFileUrl(music.id);
      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      print('Error loading music: $e');
    }
  }
  
  // 播放/暂停切换
  Future<void> togglePlay() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }
  
  // 暂停
  Future<void> pause() async {
    await _player.pause();
  }
  
  // 继续播放
  Future<void> resume() async {
    await _player.play();
  }
  
  // 停止
  Future<void> stop() async {
    await _player.stop();
  }
  
  // 下一首
  Future<void> playNext() async {
    if (_playlist.isEmpty) return;
    
    int nextIndex;
    if (_playMode == PlayMode.shuffle) {
      nextIndex = _getRandomIndex();
    } else {
      nextIndex = (_currentIndex + 1) % _playlist.length;
    }
    
    await playAt(nextIndex);
  }
  
  // 上一首
  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;
    
    int prevIndex;
    if (_playMode == PlayMode.shuffle) {
      prevIndex = _getRandomIndex();
    } else {
      prevIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    }
    
    await playAt(prevIndex);
  }
  
  int _getRandomIndex() {
    if (_playlist.length <= 1) return 0;
    int newIndex;
    do {
      newIndex = DateTime.now().millisecondsSinceEpoch % _playlist.length;
    } while (newIndex == _currentIndex);
    return newIndex;
  }
  
  // 跳转到指定位置
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }
  
  // 设置播放模式
  void setPlayMode(PlayMode mode) {
    _playMode = mode;
  }
  
  // 循环切换播放模式
  PlayMode togglePlayMode() {
    switch (_playMode) {
      case PlayMode.sequence:
        _playMode = PlayMode.loop;
        break;
      case PlayMode.loop:
        _playMode = PlayMode.single;
        break;
      case PlayMode.single:
        _playMode = PlayMode.shuffle;
        break;
      case PlayMode.shuffle:
        _playMode = PlayMode.sequence;
        break;
    }
    return _playMode;
  }
  
  // 设置音量 (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }
  
  double get volume => _player.volume;
  
  // 释放资源
  Future<void> dispose() async {
    await _player.dispose();
  }
}
