import 'music.dart';

class Playlist {
  final int id;
  final int userId;
  final String name;
  final String? description;
  final int musicCount;
  final String? createdAt;
  final String? updatedAt;
  final int? firstMusicId;
  final String? firstMusicCover;
  final PlaylistCreator? creator;

  Playlist({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.musicCount = 0,
    this.createdAt,
    this.updatedAt,
    this.firstMusicId,
    this.firstMusicCover,
    this.creator,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as int,
      userId: json['userId'] as int? ?? 0,
      name: json['name'] as String,
      description: json['description'] as String?,
      musicCount: json['musicCount'] as int? ?? 0,
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      firstMusicId: json['firstMusicId'] as int?,
      firstMusicCover: json['firstMusicCover'] as String?,
      creator: json['creator'] != null
          ? PlaylistCreator.fromJson(json['creator'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'musicCount': musicCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'firstMusicId': firstMusicId,
      'firstMusicCover': firstMusicCover,
      'creator': creator?.toJson(),
    };
  }

  String get coverUrl {
    if (firstMusicCover != null && firstMusicCover!.isNotEmpty) {
      if (firstMusicCover!.startsWith('http')) {
        return firstMusicCover!;
      }
      return 'https://music.cnmsb.xin$firstMusicCover';
    }
    if (firstMusicId != null) {
      return 'https://music.cnmsb.xin/api/music/cover/$firstMusicId';
    }
    return 'https://music.cnmsb.xin/api/user/avatar/default';
  }
}

class PlaylistCreator {
  final int id;
  final String username;

  PlaylistCreator({
    required this.id,
    required this.username,
  });

  factory PlaylistCreator.fromJson(Map<String, dynamic> json) {
    return PlaylistCreator(
      id: json['id'] as int,
      username: json['username'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
    };
  }
}

class PlaylistMusic {
  final Music music;
  final int position;
  final String? addedAt;

  PlaylistMusic({
    required this.music,
    required this.position,
    this.addedAt,
  });

  factory PlaylistMusic.fromJson(Map<String, dynamic> json) {
    return PlaylistMusic(
      music: Music.fromJson(json),
      position: json['position'] as int? ?? 0,
      addedAt: json['addedAt']?.toString(),
    );
  }
}
