class ProfileModel {
  final String id;
  final String username;
  final String? fullName;
  final String? bio;
  final String? avatarUrl;
  final String? coverUrl;
  final DateTime createdAt;
  final int postsCount;
  final int followersCount;
  final int followingCount;

  const ProfileModel({
    required this.id,
    required this.username,
    this.fullName,
    this.bio,
    this.avatarUrl,
    this.coverUrl,
    required this.createdAt,
    this.postsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
  });

  String get displayName => fullName?.isNotEmpty == true ? fullName! : username;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      fullName: json['full_name'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      postsCount: json['posts_count'] as int? ?? 0,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'full_name': fullName,
        'bio': bio,
        'avatar_url': avatarUrl,
        'cover_url': coverUrl,
        'created_at': createdAt.toIso8601String(),
      };

  ProfileModel copyWith({
    String? username,
    String? fullName,
    String? bio,
    String? avatarUrl,
    String? coverUrl,
    int? postsCount,
    int? followersCount,
    int? followingCount,
  }) {
    return ProfileModel(
      id: id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      createdAt: createdAt,
      postsCount: postsCount ?? this.postsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
    );
  }
}
