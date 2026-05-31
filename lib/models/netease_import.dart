/// 网易云歌单导入相关数据模型
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
