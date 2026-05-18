import '../../profile/domain/profile_model.dart';

class ConversationModel {
  final String id;
  final String participant1;
  final String participant2;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final String? lastMessageSenderId;
  final ProfileModel? otherUser; // populated on the fly

  const ConversationModel({
    required this.id,
    required this.participant1,
    required this.participant2,
    this.lastMessage,
    this.lastMessageAt,
    required this.createdAt,
    this.lastMessageSenderId,
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
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastMessageSenderId: json['last_message_sender'] != null
          ? (json['last_message_sender'] is Map ? json['last_message_sender']['sender_id'] as String? : null)
          : null,
      otherUser: otherUser,
    );
  }

  String getOtherUserId(String currentUserId) {
    return participant1 == currentUserId ? participant2 : participant1;
  }
}
