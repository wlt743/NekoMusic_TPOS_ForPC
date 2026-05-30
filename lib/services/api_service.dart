import 'package:dio/dio.dart';
import '../models/music.dart';
import '../models/user.dart';
import '../models/playlist.dart';

class ApiService {
  static const String baseUrl = 'https://music.cnmsb.xin';
  
  late final Dio _dio;
  String? _token;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = _token;
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        print('API Error: ${error.message}');
        return handler.next(error);
      },
    ));
  }

  void setToken(String? token) {
    _token = token;
  }

  // ==================== 用户相关 API ====================

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _dio.post('/api/user/login', data: {
      'username': username,
      'password': password,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String email,
    required String verificationCode,
  }) async {
    final response = await _dio.post('/api/user/register', data: {
      'username': username,
      'password': password,
      'email': email,
      'verificationCode': verificationCode,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> sendVerificationCode({
    required String email,
    String? username,
    required String captchaPassToken,
  }) async {
    final response = await _dio.post('/api/user/send-verification', data: {
      'email': email,
      'username': username,
      'captchaPassToken': captchaPassToken,
    });
    return response.data;
  }

  Future<List<Music>> getFavorites() async {
    final response = await _dio.get('/api/user/favorites');
    if (response.data['success'] == true) {
      final list = response.data['favorites'] as List;
      return list.map((e) => Music.fromJson(e)).toList();
    }
    return [];
  }

  Future<bool> addFavorite(int musicId) async {
    final response = await _dio.post('/api/user/favorites', data: {
      'musicId': musicId,
    });
    return response.data['success'] == true;
  }

  Future<bool> addFavorites(List<int> musicIds) async {
    final response = await _dio.post('/api/user/favorites', data: {
      'musicIds': musicIds,
    });
    return response.data['success'] == true;
  }

  Future<bool> removeFavorite(int musicId) async {
    final response = await _dio.delete('/api/user/favorites/$musicId');
    return response.data['success'] == true;
  }

  Future<List<Music>> getDailyRecommendations() async {
    final response = await _dio.get('/api/user/recommendations/daily');
    if (response.data['success'] == true) {
      final list = response.data['data'] as List;
      return list.map((e) => Music.fromJson(e)).toList();
    }
    return [];
  }

  // ==================== 音乐相关 API ====================

  Future<List<Music>> searchMusic(String query) async {
    final response = await _dio.post('/api/music/search', data: {
      'query': query,
    });
    if (response.data['success'] == true && response.data['results'] != null) {
      final list = response.data['results'] as List;
      return list.map((e) => Music.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<Music?>> searchMusicBatch(List<Map<String, String>> items) async {
    final response = await _dio.post('/api/music/search', data: {
      'items': items,
    });
    if (response.data['success'] == true && response.data['results'] != null) {
      final list = response.data['results'] as List;
      return list.map((e) => e != null ? Music.fromJson(e) : null).toList();
    }
    return [];
  }

  Future<Music?> getMusicInfo(int id) async {
    final response = await _dio.get('/api/music/info/$id');
    if (response.data['success'] == true) {
      return Music.fromJson(response.data['data']);
    }
    return null;
  }

  Future<String?> getLyrics(int id) async {
    final response = await _dio.get('/api/music/lyrics/$id');
    if (response.data['success'] == true) {
      return response.data['data'] as String?;
    }
    return null;
  }

  Future<List<Music>> getRanking({int limit = 200}) async {
    final response = await _dio.get('/api/music/ranking', queryParameters: {
      'limit': limit,
    });
    if (response.data['success'] == true) {
      final list = response.data['data'] as List;
      return list.map((e) => Music.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<Music>> getLatestMusic({int limit = 300}) async {
    final response = await _dio.get('/api/music/latest', queryParameters: {
      'limit': limit,
    });
    if (response.data['success'] == true) {
      final list = response.data['data'] as List;
      return list.map((e) => Music.fromJson(e)).toList();
    }
    return [];
  }

  // ==================== 歌单相关 API ====================

  Future<List<Playlist>> searchPlaylists(String query) async {
    final response = await _dio.post('/api/playlists/search', data: {
      'query': query,
    });
    if (response.data['success'] == true) {
      final list = response.data['results'] as List;
      return list.map((e) => Playlist.fromJson(e)).toList();
    }
    return [];
  }

  Future<Playlist?> getPlaylistDetail(int id) async {
    final response = await _dio.get('/api/playlist/$id');
    if (response.data['success'] == true) {
      return Playlist.fromJson(response.data['playlist']);
    }
    return null;
  }

  Future<List<Playlist>> getMyPlaylists() async {
    final response = await _dio.get('/api/user/playlists');
    if (response.data['success'] == true) {
      final list = response.data['playlists'] as List;
      return list.map((e) => Playlist.fromJson(e)).toList();
    }
    return [];
  }

  Future<Playlist?> createPlaylist(String name, {String? description}) async {
    final response = await _dio.post('/api/user/playlist/create', data: {
      'name': name,
      'description': description,
    });
    if (response.data['success'] == true) {
      return Playlist.fromJson(response.data['playlist']);
    }
    return null;
  }

  Future<bool> updatePlaylist(int id, String name, {String? description}) async {
    final response = await _dio.post('/api/user/playlist/update', data: {
      'id': id,
      'name': name,
      'description': description,
    });
    return response.data['success'] == true;
  }

  Future<bool> deletePlaylist(int id) async {
    final response = await _dio.post('/api/user/playlist/delete', data: {
      'id': id,
    });
    return response.data['success'] == true;
  }

  Future<List<Music>> getPlaylistMusic(int playlistId) async {
    final response = await _dio.get('/api/user/playlist/music/$playlistId');
    if (response.data['success'] == true) {
      final list = response.data['musicList'] as List;
      return list.map((e) => Music.fromJson(e)).toList();
    }
    return [];
  }

  Future<bool> addMusicToPlaylist(int playlistId, List<int> musicIds) async {
    final response = await _dio.post('/api/user/playlist/music/add', data: {
      'playlistId': playlistId,
      'musicIds': musicIds,
    });
    return response.data['success'] == true;
  }

  Future<bool> removeMusicFromPlaylist(int playlistId, List<int> musicIds) async {
    final response = await _dio.post('/api/user/playlist/music/remove', data: {
      'playlistId': playlistId,
      'musicIds': musicIds,
    });
    return response.data['success'] == true;
  }

  // ==================== 收藏歌单 API ====================

  Future<List<Playlist>> getFavoritePlaylists() async {
    final response = await _dio.get('/api/user/favorite-playlists');
    if (response.data['success'] == true) {
      final list = response.data['playlists'] as List;
      return list.map((e) => Playlist.fromJson(e)).toList();
    }
    return [];
  }

  Future<bool> favoritePlaylist(int playlistId) async {
    final response = await _dio.post('/api/user/favorite-playlists', data: {
      'playlistId': playlistId,
    });
    return response.data['success'] == true;
  }

  Future<bool> unfavoritePlaylist(int playlistId) async {
    final response = await _dio.delete('/api/user/favorite-playlists/$playlistId');
    return response.data['success'] == true;
  }

  // ==================== 歌手相关 API ====================

  Future<Map<String, dynamic>?> searchArtist(String query) async {
    final response = await _dio.post('/api/artists/search', data: {
      'query': query,
    });
    if (response.data['success'] == true) {
      return response.data['artist'];
    }
    return null;
  }

  // ==================== URL 生成 ====================

  static String getMusicFileUrl(int id) => '$baseUrl/api/music/file/$id';
  static String getMusicCoverUrl(int id) => '$baseUrl/api/music/cover/$id';
  static String getUserAvatarUrl(int id) => '$baseUrl/api/user/avatar/$id';
}
