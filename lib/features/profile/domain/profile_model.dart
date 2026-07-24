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
  final List<String> interests;
  final bool isPrivateProfile;

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
    this.interests = const [],
    this.isPrivateProfile = false,
  });

  String get displayName => fullName?.isNotEmpty == true ? fullName! : username;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'] ?? json['createdAt'];
    return ProfileModel(
      id: (json['id'] ?? '') as String,
      username: (json['username'] ?? '') as String,
      fullName: (json['full_name'] ?? json['fullName']) as String?,
      bio: json['bio'] as String?,
      avatarUrl: (json['avatar_url'] ?? json['avatarUrl']) as String?,
      coverUrl: (json['cover_url'] ?? json['coverUrl']) as String?,
      createdAt: createdAtRaw != null
          ? DateTime.parse(createdAtRaw.toString())
          : DateTime.now(),
      postsCount: (json['posts_count'] ?? json['postsCount'] ?? 0) as int,
      followersCount: (json['followers_count'] ?? json['followersCount'] ?? 0) as int,
      followingCount: (json['following_count'] ?? json['followingCount'] ?? 0) as int,
      interests: (json['interests'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      isPrivateProfile: (json['is_private_profile'] ?? json['isPrivateProfile'] ?? false) as bool,
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
        'interests': interests,
        'is_private_profile': isPrivateProfile,
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
    List<String>? interests,
    bool? isPrivateProfile,
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
      interests: interests ?? this.interests,
      isPrivateProfile: isPrivateProfile ?? this.isPrivateProfile,
    );
  }
}
