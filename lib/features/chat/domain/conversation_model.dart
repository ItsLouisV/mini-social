import '../../profile/domain/profile_model.dart';
import 'conversation_member_model.dart';

class ConversationModel {
  final String id;
  final String type; // 'direct' | 'group'
  final String? participant1;
  final String? participant2;
  final String? name; // Group name
  final String? avatarUrl; // Group avatar
  final String? description; // Group description
  final String? createdBy;
  final String? lastMessageId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final DateTime createdAt;

  // ── Group permission toggles (only relevant for type == 'group') ──────────
  final bool adminOnlyMessaging;    // Only owner/admin can send messages
  final bool allowMemberInvite;     // Members can invite new members
  final bool allowMemberPin;        // Members can pin/unpin messages
  final bool allowMemberMentionAll; // Members can @everyone
  final bool allowMemberEditInfo;   // Members can edit name/avatar/description

  // Custom states from conversation_members & profiles
  final ConversationMemberModel? myMemberState;
  final ProfileModel? otherUser; // For 1-1 chats
  final List<ConversationMemberModel>? members; // Loaded for group details
  final int? _legacyP2Unread;
  final bool? _legacyP2Pinned;
  final bool? _legacyP2Hidden;

  const ConversationModel({
    required this.id,
    this.type = 'direct',
    this.participant1,
    this.participant2,
    this.name,
    this.avatarUrl,
    this.description,
    this.createdBy,
    this.lastMessageId,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    required this.createdAt,
    this.myMemberState,
    this.otherUser,
    this.members,
    this.adminOnlyMessaging = false,
    this.allowMemberInvite = true,
    this.allowMemberPin = true,
    this.allowMemberMentionAll = true,
    this.allowMemberEditInfo = true,
    int? legacyP2Unread,
    bool? legacyP2Pinned,
    bool? legacyP2Hidden,
  })  : _legacyP2Unread = legacyP2Unread,
        _legacyP2Pinned = legacyP2Pinned,
        _legacyP2Hidden = legacyP2Hidden;

  bool get isGroup => type == 'group';
  bool get isDirect => type == 'direct';

  // Backward compatible & clean helper getters for UI
  String get groupName => name ?? 'Nhóm trò chuyện';
  String? get groupAvatarUrl => avatarUrl;
  String? get groupAdminId => createdBy;
  List<String> get memberIds => members?.map((m) => m.userId).toList() ?? [];

  int get unreadCount => myMemberState?.unreadCount ?? 0;
  bool get isPinnedState => myMemberState?.isPinned ?? false;
  bool get isHiddenState => myMemberState?.isHidden ?? false;
  bool get isMuted => myMemberState?.isMuted ?? false;

  int get p1UnreadCount => getUnreadCount(participant1);
  int get p2UnreadCount => getUnreadCount(participant2);
  bool get p1IsPinned => isPinned(participant1);
  bool get p2IsPinned => isPinned(participant2);
  bool get p1IsHidden => isHidden(participant1);
  bool get p2IsHidden => isHidden(participant2);

  int getUnreadCount([String? userId]) {
    if (userId != null && userId == participant2 && _legacyP2Unread != null) {
      return _legacyP2Unread!;
    }
    if (userId != null && myMemberState != null) {
      if (myMemberState!.userId == userId) return myMemberState!.unreadCount;
      return 0;
    }
    return unreadCount;
  }

  bool checkIsPinned([String? userId]) => isPinned(userId);
  bool checkIsHidden([String? userId]) => isHidden(userId);

  bool isPinned([String? userId]) {
    if (userId != null && userId == participant2 && _legacyP2Pinned != null) {
      return _legacyP2Pinned!;
    }
    if (userId != null && myMemberState != null) {
      if (myMemberState!.userId == userId) return myMemberState!.isPinned;
      return false;
    }
    return isPinnedState;
  }

  bool isHidden([String? userId]) {
    if (userId != null && userId == participant2 && _legacyP2Hidden != null) {
      return _legacyP2Hidden!;
    }
    if (userId != null && myMemberState != null) {
      if (myMemberState!.userId == userId) return myMemberState!.isHidden;
      return false;
    }
    return isHiddenState;
  }

  String getOtherUserId(String currentUserId) {
    if (participant1 != null && participant2 != null) {
      return participant1 == currentUserId ? participant2! : participant1!;
    }
    return '';
  }

  factory ConversationModel.fromJson(
    Map<String, dynamic> json, {
    ConversationMemberModel? myMemberState,
    ProfileModel? otherUser,
    List<ConversationMemberModel>? members,
  }) {
    // If conversation_members were joined in json
    ConversationMemberModel? memberState = myMemberState;
    if (memberState == null && json['conversation_members'] != null) {
      final rawMembers = json['conversation_members'];
      if (rawMembers is List && rawMembers.isNotEmpty) {
        memberState = ConversationMemberModel.fromJson(
          Map<String, dynamic>.from(rawMembers.first),
        );
      } else if (rawMembers is Map) {
        memberState = ConversationMemberModel.fromJson(
          Map<String, dynamic>.from(rawMembers),
        );
      }
    }
    if (memberState == null && (json['p1_unread_count'] != null || json['p1_is_pinned'] != null || json['p1_is_hidden'] != null)) {
      memberState = ConversationMemberModel(
        id: (json['id'] as String?) ?? '',
        conversationId: (json['id'] as String?) ?? '',
        userId: (json['participant_1'] as String?) ?? '',
        unreadCount: (json['p1_unread_count'] as int?) ?? 0,
        isPinned: (json['p1_is_pinned'] as bool?) ?? false,
        isHidden: (json['p1_is_hidden'] as bool?) ?? false,
      );
    }

    List<ConversationMemberModel>? parsedMembers = members;
    if (parsedMembers == null && json['members_list'] != null && json['members_list'] is List) {
      parsedMembers = (json['members_list'] as List)
          .map((m) => ConversationMemberModel.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }

    String? senderId = json['last_message_sender_id'] as String?;
    if (senderId == null && json['last_message_sender'] != null) {
      if (json['last_message_sender'] is Map) {
        senderId = json['last_message_sender']['sender_id'] as String?;
      }
    }

    return ConversationModel(
      id: json['id'] as String,
      type: json['type'] as String? ?? (json['is_group'] == true ? 'group' : 'direct'),
      participant1: json['participant_1'] as String?,
      participant2: json['participant_2'] as String?,
      name: (json['name'] ?? json['group_name']) as String?,
      avatarUrl: (json['avatar_url'] ?? json['group_avatar_url']) as String?,
      description: json['description'] as String?,
      createdBy: (json['created_by'] ?? json['group_admin_id']) as String?,
      lastMessageId: json['last_message_id'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String).toLocal()
          : null,
      lastMessageSenderId: senderId,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
      myMemberState: memberState,
      otherUser: otherUser,
      members: parsedMembers,
      adminOnlyMessaging: json['admin_only_messaging'] as bool? ?? false,
      allowMemberInvite: json['allow_member_invite'] as bool? ?? true,
      allowMemberPin: json['allow_member_pin'] as bool? ?? true,
      allowMemberMentionAll: json['allow_member_mention_all'] as bool? ?? true,
      allowMemberEditInfo: json['allow_member_edit_info'] as bool? ?? true,
      legacyP2Unread: json['p2_unread_count'] as int?,
      legacyP2Pinned: json['p2_is_pinned'] as bool?,
      legacyP2Hidden: json['p2_is_hidden'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'participant_1': participant1,
      'participant_2': participant2,
      'name': name,
      'avatar_url': avatarUrl,
      'description': description,
      'created_by': createdBy,
      'last_message_id': lastMessageId,
      'last_message': lastMessage,
      'last_message_at': lastMessageAt?.toUtc().toIso8601String(),
      'last_message_sender_id': lastMessageSenderId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'admin_only_messaging': adminOnlyMessaging,
      'allow_member_invite': allowMemberInvite,
      'allow_member_pin': allowMemberPin,
      'allow_member_mention_all': allowMemberMentionAll,
      'allow_member_edit_info': allowMemberEditInfo,
    };
  }

  ConversationModel copyWith({
    String? name,
    String? avatarUrl,
    String? description,
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastMessageId,
    String? lastMessageSenderId,
    ConversationMemberModel? myMemberState,
    ProfileModel? otherUser,
    List<ConversationMemberModel>? members,
    bool? adminOnlyMessaging,
    bool? allowMemberInvite,
    bool? allowMemberPin,
    bool? allowMemberMentionAll,
    bool? allowMemberEditInfo,
  }) {
    return ConversationModel(
      id: id,
      type: type,
      participant1: participant1,
      participant2: participant2,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      description: description ?? this.description,
      createdBy: createdBy,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      createdAt: createdAt,
      myMemberState: myMemberState ?? this.myMemberState,
      otherUser: otherUser ?? this.otherUser,
      members: members ?? this.members,
      adminOnlyMessaging: adminOnlyMessaging ?? this.adminOnlyMessaging,
      allowMemberInvite: allowMemberInvite ?? this.allowMemberInvite,
      allowMemberPin: allowMemberPin ?? this.allowMemberPin,
      allowMemberMentionAll: allowMemberMentionAll ?? this.allowMemberMentionAll,
      allowMemberEditInfo: allowMemberEditInfo ?? this.allowMemberEditInfo,
    );
  }
}
