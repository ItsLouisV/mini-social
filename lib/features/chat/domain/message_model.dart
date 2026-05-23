class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String? content;
  final String? mediaUrl;
  final String messageType; // 'text' | 'image' | 'voice'
  final bool isSeen;
  final DateTime createdAt;
  final String? replyToMessageId;
  final String? callId;

  // Thuộc tính để lưu tạm UI state cho tin nhắn reply
  final MessageModel? replyToMessage;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.content,
    this.mediaUrl,
    this.messageType = 'text',
    this.isSeen = false,
    required this.createdAt,
    this.replyToMessageId,
    this.replyToMessage,
    this.callId,
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
      replyToMessageId: json['reply_to_message_id'] as String?,
      replyToMessage: json['reply_to_message'] != null
          ? (json['reply_to_message'] is List
              ? ((json['reply_to_message'] as List).isNotEmpty
                  ? MessageModel.fromJson((json['reply_to_message'] as List).first as Map<String, dynamic>)
                  : null)
              : MessageModel.fromJson(json['reply_to_message'] as Map<String, dynamic>))
          : null,
      callId: json['call_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'media_url': mediaUrl,
      'message_type': messageType,
      'is_seen': isSeen,
      'created_at': createdAt.toUtc().toIso8601String(),
      'reply_to_message_id': replyToMessageId,
      'call_id': callId,
    };
  }

  bool get isText => messageType == 'text';
  bool get isImage => messageType == 'image';
  bool get isCall => messageType == 'call_log';
}
