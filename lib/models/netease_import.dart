/// 外部歌单导入相关数据模型
/// 复刻自 NekoMusicForPc 的 ApiClient::NeteasePlaylistInfo / BatchSearchResult 等结构。
library;

/// 网易云歌单中的单条曲目
class NeteaseTrack {
  final String name;
  final String artist;

  const NeteaseTrack({required this.name, required this.artist});

  factory NeteaseTrack.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String? ?? '').trim();
    // ar 数组里每个元素的 name 用 " / " 连接，与 PC/Android 端保持一致
    final artists = <String>[];
    final ar = json['ar'];
    if (ar is List) {
      for (final a in ar) {
        if (a is Map) {
          final n = (a['name'] as String? ?? '').trim();
          if (n.isNotEmpty) artists.add(n);
        }
      }
    }
    return NeteaseTrack(name: name, artist: artists.join(' / '));
  }
}

/// 网易云歌单详情
class NeteasePlaylistInfo {
  final int id;
  final String name;
  final int trackCount;
  final List<NeteaseTrack> tracks;

  const NeteasePlaylistInfo({
    required this.id,
    required this.name,
    required this.trackCount,
    required this.tracks,
  });

  factory NeteasePlaylistInfo.fromNeteaseJson(
    Map<String, dynamic> playlist, {
    required int fallbackId,
  }) {
    int id = 0;
    final rawId = playlist['id'];
    if (rawId is int) {
      id = rawId;
    } else if (rawId is num) {
      id = rawId.toInt();
    } else if (rawId is String) {
      id = int.tryParse(rawId) ?? 0;
    }
    if (id <= 0) id = fallbackId;

    final tracks = <NeteaseTrack>[];
    final rawTracks = playlist['tracks'];
    if (rawTracks is List) {
      for (final t in rawTracks) {
        if (t is Map<String, dynamic>) {
          final track = NeteaseTrack.fromJson(t);
          if (track.name.isNotEmpty) tracks.add(track);
        } else if (t is Map) {
          final track = NeteaseTrack.fromJson(Map<String, dynamic>.from(t));
          if (track.name.isNotEmpty) tracks.add(track);
        }
      }
    }

    return NeteasePlaylistInfo(
      id: id,
      name: (playlist['name'] as String? ?? '').trim(),
      trackCount: (playlist['trackCount'] as num?)?.toInt() ?? tracks.length,
      tracks: tracks,
    );
  }
}

/// QQ 音乐歌单中的单条曲目
class QqMusicTrack {
  final String name;
  final String artist;

  const QqMusicTrack({required this.name, required this.artist});

  factory QqMusicTrack.fromJson(Map<String, dynamic> json) {
    final name = _firstString(json, ['name', 'songname', 'songName', 'title']);
    final artists = <String>[];
    final singer = json['singer'] ?? json['artists'] ?? json['ar'];
    if (singer is List) {
      for (final item in singer) {
        if (item is Map) {
          final n = _firstString(
            Map<String, dynamic>.from(item),
            ['name', 'singername', 'title'],
          );
          if (n.isNotEmpty) artists.add(n);
        } else if (item is String && item.trim().isNotEmpty) {
          artists.add(item.trim());
        }
      }
    } else if (singer is String && singer.trim().isNotEmpty) {
      artists.add(singer.trim());
    }

    return QqMusicTrack(name: name, artist: artists.join(' / '));
  }
}

/// QQ 音乐歌单详情
class QqMusicPlaylistInfo {
  final String id;
  final String name;
  final int trackCount;
  final List<QqMusicTrack> tracks;

  const QqMusicPlaylistInfo({
    required this.id,
    required this.name,
    required this.trackCount,
    required this.tracks,
  });

  factory QqMusicPlaylistInfo.fromQqJson(
    Map<String, dynamic> playlist, {
    required String fallbackId,
  }) {
    final rawTracks = _firstValue(playlist, [
      'songlist',
      'songList',
      'tracks',
      'list',
      'songs',
    ]);

    final tracks = <QqMusicTrack>[];
    if (rawTracks is List) {
      for (final item in rawTracks) {
        final song = _normalizeQqSongJson(item);
        if (song == null) continue;
        final track = QqMusicTrack.fromJson(song);
        if (track.name.isNotEmpty) tracks.add(track);
      }
    }

    final rawId = _firstValue(playlist, ['disstid', 'dissid', 'id']);
    final id = rawId?.toString().trim();
    final count = _firstInt(playlist, [
          'songnum',
          'songNum',
          'total_song_num',
          'trackCount',
          'total',
        ]) ??
        tracks.length;
    final dirInfo = _firstMap(playlist, ['dirinfo', 'dirInfo', 'info']);
    final name = _firstString(playlist, ['dissname', 'name', 'title']);
    final fallbackName = dirInfo == null
        ? ''
        : _firstString(dirInfo, ['dissname', 'dirName', 'name', 'title']);

    return QqMusicPlaylistInfo(
      id: (id == null || id.isEmpty) ? fallbackId : id,
      name: name.isEmpty ? fallbackName : name,
      trackCount: count,
      tracks: tracks,
    );
  }
}

Map<String, dynamic>? _normalizeQqSongJson(dynamic item) {
  if (item is! Map) return null;
  final map = Map<String, dynamic>.from(item);
  final nested =
      map['songInfo'] ?? map['songinfo'] ?? map['musicData'] ?? map['data'];
  if (nested is Map) return Map<String, dynamic>.from(nested);
  return map;
}

dynamic _firstValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) return json[key];
  }
  return null;
}

String _firstString(Map<String, dynamic> json, List<String> keys) {
  final value = _firstValue(json, keys);
  return value?.toString().trim() ?? '';
}

int? _firstInt(Map<String, dynamic> json, List<String> keys) {
  final value = _firstValue(json, keys);
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

Map<String, dynamic>? _firstMap(Map<String, dynamic> json, List<String> keys) {
  final value = _firstValue(json, keys);
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

/// 批量搜索用的查询项
class NeteaseSearchItem {
  final String title;
  final String artist;

  const NeteaseSearchItem({required this.title, required this.artist});

  Map<String, String> toJson() => {'title': title, 'artist': artist};
}

/// 批量搜索结果汇总
class BatchSearchResult {
  final bool success;
  final String message;
  final List<int> matchedMusicIds;
  final int successCount;
  final int failCount;

  const BatchSearchResult({
    required this.success,
    this.message = '',
    this.matchedMusicIds = const [],
    this.successCount = 0,
    this.failCount = 0,
  });
}

/// 批量添加（歌单/收藏）结果。
/// 对应文档：成功返回 addedCount；部分失败 HTTP 400 时返回 failedMusicIds，
/// 已成功添加的曲目仍生效（多为「已存在」）。
class BatchAddResult {
  final bool success;
  final String message;
  final int addedCount;
  final List<int> failedMusicIds;

  const BatchAddResult({
    required this.success,
    this.message = '',
    this.addedCount = 0,
    this.failedMusicIds = const [],
  });
}

/// 导入异常（携带可展示给用户的消息）
class NeteaseImportException implements Exception {
  final String message;
  NeteaseImportException(this.message);

  @override
  String toString() => message;
}
