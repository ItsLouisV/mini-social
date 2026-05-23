import 'message_model.dart';

class PinnedMessageModel {
  final String id;
  final String conversationId;
  final String messageId;
  final String pinnedBy;
  final DateTime pinnedAt;
  final MessageModel? message;

  const PinnedMessageModel({
    required this.id,
    required this.conversationId,
    required this.messageId,
    required this.pinnedBy,
    required this.pinnedAt,
    this.message,
  });

  factory PinnedMessageModel.fromJson(Map<String, dynamic> json) {
    return PinnedMessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      messageId: json['message_id'] as String,
      pinnedBy: json['pinned_by'] as String,
      pinnedAt: DateTime.parse(json['pinned_at'] as String).toLocal(),
      message: json['message'] != null
          ? MessageModel.fromJson(json['message'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'message_id': messageId,
      'pinned_by': pinnedBy,
      'pinned_at': pinnedAt.toUtc().toIso8601String(),
    };
  }
}
