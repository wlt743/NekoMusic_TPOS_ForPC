class User {
  final int id;
  final String username;
  final String email;
  final String? createdAt;
  final bool isVip;
  final String? vipExpiresAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.createdAt,
    this.isVip = false,
    this.vipExpiresAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      createdAt: json['createdAt'] as String?,
      isVip: json['isVip'] as bool? ?? false,
      vipExpiresAt: json['vipExpiresAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'createdAt': createdAt,
      'isVip': isVip,
      'vipExpiresAt': vipExpiresAt,
    };
  }

  String get avatarUrl => 'https://music.cnmsb.xin/api/user/avatar/$id';

  User copyWith({
    int? id,
    String? username,
    String? email,
    String? createdAt,
    bool? isVip,
    String? vipExpiresAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      isVip: isVip ?? this.isVip,
      vipExpiresAt: vipExpiresAt ?? this.vipExpiresAt,
    );
  }
}
