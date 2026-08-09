/// Model for a banned member record in a group conversation.
class GroupBanModel {
  final String id;
  final String conversationId;
  final String userId;
  final String? bannedBy;
  final String? reason;
  final DateTime bannedAt;
  final DateTime? unbannedAt;
  final bool isActive;

  // Joined profile data (optional — loaded when needed)
  final String? userDisplayName;
  final String? userAvatarUrl;
  final String? userUsername;

  const GroupBanModel({
    required this.id,
    required this.conversationId,
    required this.userId,
    this.bannedBy,
    this.reason,
    required this.bannedAt,
    this.unbannedAt,
    this.isActive = true,
    this.userDisplayName,
    this.userAvatarUrl,
    this.userUsername,
  });

  factory GroupBanModel.fromJson(Map<String, dynamic> json) {
    // Support joined profile data via `user:profiles(...)`
    final userProfile = json['user'];
    String? displayName;
    String? avatarUrl;
    String? username;
    if (userProfile is Map<String, dynamic>) {
      displayName = userProfile['full_name'] as String?;
      avatarUrl = userProfile['avatar_url'] as String?;
      username = userProfile['username'] as String?;
    }

    return GroupBanModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      userId: json['user_id'] as String,
      bannedBy: json['banned_by'] as String?,
      reason: json['reason'] as String?,
      bannedAt: DateTime.parse(json['banned_at'] as String).toLocal(),
      unbannedAt: json['unbanned_at'] != null
          ? DateTime.parse(json['unbanned_at'] as String).toLocal()
          : null,
      isActive: json['is_active'] as bool? ?? true,
      userDisplayName: displayName,
      userAvatarUrl: avatarUrl,
      userUsername: username,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'user_id': userId,
        'banned_by': bannedBy,
        'reason': reason,
        'banned_at': bannedAt.toUtc().toIso8601String(),
        'unbanned_at': unbannedAt?.toUtc().toIso8601String(),
        'is_active': isActive,
      };
}
