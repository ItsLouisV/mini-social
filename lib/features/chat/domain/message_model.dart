class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String? content;
  final String? mediaUrl;
  final String messageType; // 'text' | 'image' | 'voice'
  final bool isSeen;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.content,
    this.mediaUrl,
    this.messageType = 'text',
    this.isSeen = false,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String?,
      mediaUrl: json['media_url'] as String?,
      messageType: json['message_type'] as String? ?? 'text',
      isSeen: json['is_seen'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  bool get isText => messageType == 'text';
  bool get isImage => messageType == 'image';
  bool get isCall => messageType == 'call_log';
}
