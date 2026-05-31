import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/music.dart';
import '../models/user.dart';
import '../models/playlist.dart';
import '../models/netease_import.dart';

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
        // 带一个浏览器风格的 UA，降低被阿里云 WAF 反爬当作可疑客户端的概率
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
                '(KHTML, like Gecko) NekoMusic/1.0 Safari/537.36',
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

  // ==================== 网易云歌单导入 ====================

  /// 从分享文本或纯 ID 中解析网易云歌单 ID。
  /// 与 PC/Android 端一致，支持：纯数字、playlist?id=、[?&]id=、playlist/ 等格式。
  static String? parseNeteasePlaylistId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // 纯数字直接返回
    if (RegExp(r'^\d+$').hasMatch(trimmed)) return trimmed;

    final patterns = <RegExp>[
      RegExp(r'playlist\?id=(\d+)', caseSensitive: false),
      RegExp(r'[?&]id=(\d+)', caseSensitive: false),
      RegExp(r'playlist/(\d+)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(trimmed);
      if (m != null) return m.group(1);
    }
    return null;
  }

  /// 判断响应体是否为「人机验证 / WAF 拦截」页面（而非正常 JSON）。
  /// 服务端套了阿里云 WAF，短时间内请求过于频繁时会返回一段 HTML 验证页，
  /// 此时不能误报「歌单不存在」，而应提示用户稍后再试。
  bool _looksLikeWafChallenge(dynamic data) {
    if (data is String) {
      final s = data.trimLeft().toLowerCase();
      if (s.startsWith('<!doctype') || s.startsWith('<html') || s.contains('<meta')) {
        return true;
      }
      if (s.contains('captcha') || s.contains('阿里云') || s.contains('验证您是真人')) {
        return true;
      }
    }
    return false;
  }

  /// 通过服务端代理获取网易云歌单详情。
  /// 对应端点：GET /loser/playlist/detail?id={playlistId}
  ///
  /// 服务端套了阿里云 WAF 反爬，连续请求时会概率性返回 HTML 人机验证页。
  /// 该拦截是瞬时的，重试通常即可拿到正常 JSON，因此这里命中 WAF 时带退避重试。
  Future<NeteasePlaylistInfo> fetchNeteasePlaylist(
    int playlistId, {
    int maxRetries = 3,
  }) async {
    dynamic data;
    var hitWaf = false;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      Response response;
      try {
        response = await _dio.get(
          '/loser/playlist/detail',
          queryParameters: {'id': playlistId},
          options: Options(
            receiveTimeout: const Duration(seconds: 120),
            headers: {'Accept': 'application/json'},
            responseType: ResponseType.json,
          ),
        );
      } catch (e) {
        // 网络错误：还能重试就退避后重试
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
          continue;
        }
        throw NeteaseImportException('网络错误，获取歌单失败，请稍后重试');
      }

      final body = response.data;

      // 命中 WAF/人机验证页面：瞬时拦截，退避后重试
      if (_looksLikeWafChallenge(body)) {
        hitWaf = true;
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
          continue;
        }
        break;
      }

      // Content-Type 不规范时 data 可能是未解析的 JSON 字符串，兜底解析
      if (body is String) {
        try {
          data = jsonDecode(body);
        } catch (_) {
          data = null;
        }
      } else {
        data = body;
      }
      break;
    }

    if (hitWaf && data == null) {
      throw NeteaseImportException('请求被服务端的人机验证拦截，请稍后重试');
    }

    if (data is! Map) {
      throw NeteaseImportException('歌单不存在');
    }

    final code = (data['code'] as num?)?.toInt() ?? -1;
    if (code != 200) {
      final msg = (data['message'] as String?) ??
          (data['msg'] as String?) ??
          '歌单不存在';
      throw NeteaseImportException(msg.isEmpty ? '歌单不存在' : msg);
    }

    final playlist = data['playlist'];
    if (playlist is! Map) {
      throw NeteaseImportException('歌单不存在');
    }

    return NeteasePlaylistInfo.fromNeteaseJson(
      Map<String, dynamic>.from(playlist),
      fallbackId: playlistId,
    );
  }

  /// 批量搜索匹配歌曲。
  ///
  /// 关键：服务端对曲库缺失的歌曲会实时从网易云补全入库，单批越大、需补全越多，
  /// 单次请求耗时越久——实测一次性提交整张歌单（数十首）会因网关超时返回 502。
  /// 因此这里把每批压到较小（默认 8 首），单批失败时自动重试，仍失败则把该批
  /// 当作「未匹配跳过」而不是整体抛错，保证导入流程能继续完成。
  ///
  /// onProgress 回调返回 0.0~1.0 的搜索进度，便于 UI 展示。
  Future<BatchSearchResult> batchSearchNeteaseMusic(
    List<NeteaseSearchItem> items, {
    void Function(double progress)? onProgress,
    int chunkSize = 8,
    int maxRetries = 2,
  }) async {
    if (items.isEmpty) {
      return const BatchSearchResult(success: true, message: '没有要搜索的歌曲');
    }

    final safeChunk = chunkSize < 1 ? 1 : chunkSize;
    final chunks = <List<NeteaseSearchItem>>[];
    for (var i = 0; i < items.length; i += safeChunk) {
      chunks.add(items.sublist(
        i,
        i + safeChunk > items.length ? items.length : i + safeChunk,
      ));
    }

    final matchedIds = <int>[];
    var successCount = 0;
    var failCount = 0;
    var anyApiSuccess = false;
    var lastMessage = '';

    for (var idx = 0; idx < chunks.length; idx++) {
      final chunk = chunks[idx];

      // 单批带重试：网络错误 / 5xx（如补全超时导致的 502）时退避后重试。
      Response? response;
      for (var attempt = 0; attempt <= maxRetries; attempt++) {
        try {
          response = await _dio.post(
            '/api/music/search',
            data: {'items': chunk.map((e) => e.toJson()).toList()},
            options: Options(
              receiveTimeout: const Duration(seconds: 120),
              sendTimeout: const Duration(seconds: 60),
              // 5xx 不抛异常，交由下方按状态码决定是否重试
              validateStatus: (s) => s != null && s < 600,
            ),
          );
          final status = response.statusCode ?? 0;
          if (status >= 500) {
            // 服务端补全超时等：还能重试就退避后重试
            if (attempt < maxRetries) {
              response = null;
              await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
              continue;
            }
          }
          break;
        } catch (e) {
          // 超时/网络错误：还能重试就退避后重试
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
            continue;
          }
          response = null;
        }
      }

      // 本批彻底失败：跳过这批（计入未匹配），继续后续批次，不中断整体导入
      if (response == null || (response.statusCode ?? 0) >= 400) {
        failCount += chunk.length;
        onProgress?.call((idx + 1) / chunks.length);
        continue;
      }

      // 命中 WAF/人机验证页面：立即中止并给出准确提示，而不是把全部歌曲算作未匹配
      if (_looksLikeWafChallenge(response.data)) {
        throw NeteaseImportException('请求过于频繁被服务端拦截，请稍后再试');
      }

      var root = response.data;
      if (root is String) {
        try {
          root = jsonDecode(root);
        } catch (_) {
          root = null;
        }
      }
      if (root is! Map) {
        failCount += chunk.length;
        onProgress?.call((idx + 1) / chunks.length);
        continue;
      }

      final ok = root['success'] == true;
      final message = root['message'] as String?;
      if (message != null && message.isNotEmpty) lastMessage = message;
      if (ok) anyApiSuccess = true;

      final results = root['results'];
      if ((results == null || (results is List && results.isEmpty)) && !ok) {
        // API 明确失败且无结果：本批全部算未匹配
        failCount += chunk.length;
      } else if (results is List) {
        for (final r in results) {
          if (r == null) {
            failCount++;
          } else if (r is Map) {
            final musicId = (r['id'] as num?)?.toInt() ?? 0;
            if (musicId > 0) {
              matchedIds.add(musicId);
              successCount++;
            } else {
              failCount++;
            }
          } else {
            failCount++;
          }
        }
        // 返回结果数少于请求数，缺失部分算未匹配
        if (results.length < chunk.length) {
          failCount += chunk.length - results.length;
        }
      } else {
        failCount += chunk.length;
      }

      onProgress?.call((idx + 1) / chunks.length);
    }

    return BatchSearchResult(
      success: anyApiSuccess || successCount > 0 || failCount > 0,
      message: lastMessage,
      matchedMusicIds: matchedIds,
      successCount: successCount,
      failCount: failCount,
    );
  }

  /// 把响应体解析为 BatchAddResult。
  ///
  /// 文档约定（关键）：
  /// - 成功：success=true，addedCount 为新增数量。
  /// - 部分失败 HTTP 400：success=false，addedCount + failedMusicIds（已存在/失败），
  ///   但已成功添加的曲目仍然生效。
  /// - 全部已存在 HTTP 400：success=false，无 addedCount、无 failedMusicIds，
  ///   message 形如「…失败或音乐已存在…」。这种情况应视为「全部跳过」的成功，
  ///   而不是真正失败（曲目本就在库中）。
  ///
  /// 因此只要不是鉴权/权限错误（已在调用处按状态码抛出），都按「已处理」返回，
  /// addedCount 与跳过数由调用方依据匹配总数推算，避免误报导入失败。
  BatchAddResult _parseBatchAddResponse(
    dynamic data, {
    required int requestedCount,
  }) {
    if (data is! Map) {
      // 无法解析时，保守地认为已提交（曲目按文档仍会生效）
      return BatchAddResult(success: true, addedCount: requestedCount);
    }
    final ok = data['success'] == true;
    final message = (data['message'] as String?) ?? '';
    final addedCount = (data['addedCount'] as num?)?.toInt() ?? 0;
    final failed = <int>[];
    final rawFailed = data['failedMusicIds'];
    if (rawFailed is List) {
      for (final f in rawFailed) {
        final id = (f as num?)?.toInt();
        if (id != null) failed.add(id);
      }
    }
    return BatchAddResult(
      success: ok,
      message: message,
      // 成功且未给出 addedCount 时按请求数计；失败但有 addedCount 时如实记录
      addedCount: addedCount > 0 ? addedCount : (ok ? requestedCount : 0),
      failedMusicIds: failed,
    );
  }

  /// 校验添加类响应的状态码，仅对鉴权/权限错误抛出（其余交由解析处理）。
  void _ensureNotAuthError(Response response) {
    final status = response.statusCode ?? 0;
    if (status == 401) {
      throw NeteaseImportException('登录已失效，请重新登录');
    }
    if (status == 403) {
      throw NeteaseImportException('无权限操作此歌单');
    }
    final data = response.data;
    if (data is Map) {
      final msg = (data['message'] as String?) ?? '';
      if (msg.contains('未登录') || msg.contains('请先登录')) {
        throw NeteaseImportException('请先登录');
      }
      if (msg.contains('无权限')) {
        throw NeteaseImportException('无权限操作此歌单');
      }
    }
  }

  /// 批量添加歌曲到歌单。
  /// 文档：HTTP 400 时已成功添加的曲目仍生效（已存在/失败列入 failedMusicIds），
  /// 全部已存在时也返回 400。除鉴权/权限错误外，均按「已处理」返回，避免误报失败。
  Future<BatchAddResult> batchAddMusicToPlaylist(
    int playlistId,
    List<int> musicIds,
  ) async {
    final uniqueIds = musicIds.toSet().toList();
    if (uniqueIds.isEmpty) {
      return const BatchAddResult(success: true, addedCount: 0);
    }
    final Response response;
    try {
      response = await _dio.post(
        '/api/user/playlist/music/add',
        data: {'playlistId': playlistId, 'musicIds': uniqueIds},
        // 不让 Dio 对 400 抛异常：部分/全部已存在也需要解析
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
    } catch (e) {
      throw NeteaseImportException('网络错误，添加到歌单失败');
    }
    _ensureNotAuthError(response);
    return _parseBatchAddResponse(
      response.data,
      requestedCount: uniqueIds.length,
    );
  }

  /// 为导入流程创建歌单（容错版）。
  /// 旧的 createPlaylist 直接读 response.data['success']，当被 WAF 拦截返回 HTML 字符串时
  /// 会抛 TypeError 导致「导入失败」；这里统一处理 WAF/字符串/非200，失败时抛带消息的异常。
  Future<Playlist> createNeteasePlaylist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw NeteaseImportException('请输入新歌单名称');
    }
    Response response;
    try {
      response = await _dio.post(
        '/api/user/playlist/create',
        data: {'name': trimmed},
        options: Options(validateStatus: (s) => s != null && s < 600),
      );
    } catch (e) {
      throw NeteaseImportException('网络错误，创建歌单失败');
    }

    _ensureNotAuthError(response);

    var data = response.data;
    if (_looksLikeWafChallenge(data)) {
      throw NeteaseImportException('请求被服务端的人机验证拦截，请稍后重试');
    }
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        throw NeteaseImportException('创建歌单失败：响应解析错误');
      }
    }
    if (data is! Map) {
      throw NeteaseImportException('创建歌单失败');
    }
    if (data['success'] != true) {
      final msg = (data['message'] as String?) ?? '创建歌单失败';
      throw NeteaseImportException(msg);
    }
    final playlistJson = data['playlist'];
    if (playlistJson is! Map) {
      throw NeteaseImportException('创建歌单失败：返回数据异常');
    }
    return Playlist.fromJson(Map<String, dynamic>.from(playlistJson));
  }

  /// 批量收藏歌曲。同上：除鉴权错误外均按「已处理」返回。
  Future<BatchAddResult> batchAddFavorites(List<int> musicIds) async {
    final uniqueIds = musicIds.toSet().toList();
    if (uniqueIds.isEmpty) {
      return const BatchAddResult(success: true, addedCount: 0);
    }
    final Response response;
    try {
      response = await _dio.post(
        '/api/user/favorites',
        data: {'musicIds': uniqueIds},
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
    } catch (e) {
      throw NeteaseImportException('网络错误，收藏失败');
    }
    _ensureNotAuthError(response);
    return _parseBatchAddResponse(
      response.data,
      requestedCount: uniqueIds.length,
    );
  }

  // ==================== URL 生成 ====================

  static String getMusicFileUrl(int id) => '$baseUrl/api/music/file/$id';
  static String getMusicCoverUrl(int id) => '$baseUrl/api/music/cover/$id';
  static String getUserAvatarUrl(int id) => '$baseUrl/api/user/avatar/$id';
}
