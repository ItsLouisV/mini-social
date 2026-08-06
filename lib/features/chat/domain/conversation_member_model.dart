import '../../profile/domain/profile_model.dart';

class ConversationMemberModel {
  final String id;
  final String conversationId;
  final String userId;
  final String role; // 'owner' | 'admin' | 'member'
  final DateTime? joinedAt;
  final DateTime? leftAt;
  final int unreadCount;
  final String? lastReadMessageId;
  final DateTime? lastReadAt;
  final bool isHidden;
  final bool isPinned;
  final bool isMuted;
  final String? nickname;
  final ProfileModel? profile;

  const ConversationMemberModel({
    required this.id,
    required this.conversationId,
    required this.userId,
    this.role = 'member',
    this.joinedAt,
    this.leftAt,
    this.unreadCount = 0,
    this.lastReadMessageId,
    this.lastReadAt,
    this.isHidden = false,
    this.isPinned = false,
    this.isMuted = false,
    this.nickname,
    this.profile,
  });

  bool get isOwner => role == 'owner' || role == 'creator';
  bool get isCoAdmin => role == 'admin' || role == 'co_admin';
  bool get isAdmin => isOwner || isCoAdmin;
  bool get isMember => role == 'member';

  factory ConversationMemberModel.fromJson(Map<String, dynamic> json) {
    ProfileModel? prof;
    if (json['profile'] != null && json['profile'] is Map) {
      prof = ProfileModel.fromJson(Map<String, dynamic>.from(json['profile']));
    }

    return ConversationMemberModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'member',
      joinedAt: json['joined_at'] != null ? DateTime.parse(json['joined_at'] as String).toLocal() : null,
      leftAt: json['left_at'] != null ? DateTime.parse(json['left_at'] as String).toLocal() : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      lastReadMessageId: json['last_read_message_id'] as String?,
      lastReadAt: json['last_read_at'] != null ? DateTime.parse(json['last_read_at'] as String).toLocal() : null,
      isHidden: json['is_hidden'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      isMuted: json['is_muted'] as bool? ?? false,
      nickname: json['nickname'] as String?,
      profile: prof,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'user_id': userId,
      'role': role,
      'joined_at': joinedAt?.toUtc().toIso8601String(),
      'left_at': leftAt?.toUtc().toIso8601String(),
      'unread_count': unreadCount,
      'last_read_message_id': lastReadMessageId,
      'last_read_at': lastReadAt?.toUtc().toIso8601String(),
      'is_hidden': isHidden,
      'is_pinned': isPinned,
      'is_muted': isMuted,
      'nickname': nickname,
    };
  }

  ConversationMemberModel copyWith({
    String? role,
    int? unreadCount,
    bool? isHidden,
    bool? isPinned,
    bool? isMuted,
    String? nickname,
    ProfileModel? profile,
  }) {
    return ConversationMemberModel(
      id: id,
      conversationId: conversationId,
      userId: userId,
      role: role ?? this.role,
      joinedAt: joinedAt,
      leftAt: leftAt,
      unreadCount: unreadCount ?? this.unreadCount,
      lastReadMessageId: lastReadMessageId,
      lastReadAt: lastReadAt,
      isHidden: isHidden ?? this.isHidden,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      nickname: nickname ?? this.nickname,
      profile: profile ?? this.profile,
    );
  }
}
