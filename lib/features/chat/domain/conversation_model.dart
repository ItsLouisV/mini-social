import '../../profile/domain/profile_model.dart';

class ConversationModel {
  final String id;
  final String participant1;
  final String participant2;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final String? lastMessageSenderId;
  final int p1UnreadCount;
  final int p2UnreadCount;
  final bool p1IsPinned;
  final bool p2IsPinned;
  final bool p1IsHidden;
  final bool p2IsHidden;
  final ProfileModel? otherUser; // populated on the fly

  const ConversationModel({
    required this.id,
    required this.participant1,
    required this.participant2,
    this.lastMessage,
    this.lastMessageAt,
    required this.createdAt,
    this.lastMessageSenderId,
    this.p1UnreadCount = 0,
    this.p2UnreadCount = 0,
    this.p1IsPinned = false,
    this.p2IsPinned = false,
    this.p1IsHidden = false,
    this.p2IsHidden = false,
    this.otherUser,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json,
      {ProfileModel? otherUser}) {
    return ConversationModel(
      id: json['id'] as String,
      participant1: json['participant_1'] as String,
      participant2: json['participant_2'] as String,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String).toLocal()
          : null,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      lastMessageSenderId: json['last_message_sender'] != null
          ? (json['last_message_sender'] is Map ? json['last_message_sender']['sender_id'] as String? : null)
          : null,
      p1UnreadCount: json['p1_unread_count'] as int? ?? 0,
      p2UnreadCount: json['p2_unread_count'] as int? ?? 0,
      p1IsPinned: json['p1_is_pinned'] as bool? ?? false,
      p2IsPinned: json['p2_is_pinned'] as bool? ?? false,
      p1IsHidden: json['p1_is_hidden'] as bool? ?? false,
      p2IsHidden: json['p2_is_hidden'] as bool? ?? false,
      otherUser: otherUser,
    );
  }

  String getOtherUserId(String currentUserId) {
    return participant1 == currentUserId ? participant2 : participant1;
  }

  int getUnreadCount(String currentUserId) {
    return participant1 == currentUserId ? p1UnreadCount : p2UnreadCount;
  }

  bool isPinned(String currentUserId) {
    return participant1 == currentUserId ? p1IsPinned : p2IsPinned;
  }

  bool isHidden(String currentUserId) {
    return participant1 == currentUserId ? p1IsHidden : p2IsHidden;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participant_1': participant1,
      'participant_2': participant2,
      'last_message': lastMessage,
      'last_message_at': lastMessageAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'p1_unread_count': p1UnreadCount,
      'p2_unread_count': p2UnreadCount,
      'p1_is_pinned': p1IsPinned,
      'p2_is_pinned': p2IsPinned,
      'p1_is_hidden': p1IsHidden,
      'p2_is_hidden': p2IsHidden,
    };
  }

  ConversationModel copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastMessageSenderId,
    int? p1UnreadCount,
    int? p2UnreadCount,
    bool? p1IsPinned,
    bool? p2IsPinned,
    bool? p1IsHidden,
    bool? p2IsHidden,
    ProfileModel? otherUser,
  }) {
    return ConversationModel(
      id: id,
      participant1: participant1,
      participant2: participant2,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      p1UnreadCount: p1UnreadCount ?? this.p1UnreadCount,
      p2UnreadCount: p2UnreadCount ?? this.p2UnreadCount,
      p1IsPinned: p1IsPinned ?? this.p1IsPinned,
      p2IsPinned: p2IsPinned ?? this.p2IsPinned,
      p1IsHidden: p1IsHidden ?? this.p1IsHidden,
      p2IsHidden: p2IsHidden ?? this.p2IsHidden,
      otherUser: otherUser ?? this.otherUser,
    );
  }
}
