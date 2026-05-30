class Music {
  final int id;
  final String title;
  final String artist;
  final String? album;
  final int duration;
  final String? language;
  final String? tags;
  final String? fileFormat;
  final int? playCount;
  final int? uploadUserId;
  final String? createdAt;

  Music({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    required this.duration,
    this.language,
    this.tags,
    this.fileFormat,
    this.playCount,
    this.uploadUserId,
    this.createdAt,
  });

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      id: json['id'] as int,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String?,
      duration: json['duration'] as int? ?? 0,
      language: json['language'] as String?,
      tags: json['tags'] as String?,
      fileFormat: json['fileFormat'] as String?,
      playCount: json['playCount'] as int?,
      uploadUserId: json['uploadUserId'] as int?,
      createdAt: json['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'language': language,
      'tags': tags,
      'fileFormat': fileFormat,
      'playCount': playCount,
      'uploadUserId': uploadUserId,
      'createdAt': createdAt,
    };
  }

  String get coverUrl => 'https://music.cnmsb.xin/api/music/cover/$id';
  String get fileUrl => 'https://music.cnmsb.xin/api/music/file/$id';

  String get durationFormatted {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Music && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
