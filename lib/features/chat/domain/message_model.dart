import 'dart:convert';

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String? content;
  final List<String> mediaUrls;
  final String messageType; // 'text' | 'image' | 'voice' | 'recalled'
  final bool isSeen;
  final DateTime createdAt;
  final String? replyToMessageId;
  final String? callId;
  final bool isFailed;
  final bool isSending;

  // Thuộc tính để lưu tạm UI state cho tin nhắn reply
  final MessageModel? replyToMessage;

  /// Reactions: key = emoji, value = list of userIds who reacted
  /// Ví dụ: {'👍': ['user1', 'user2'], '❤️': ['user3']}
  final Map<String, List<String>> reactions;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.content,
    this.mediaUrls = const [],
    this.messageType = 'text',
    this.isSeen = false,
    required this.createdAt,
    this.replyToMessageId,
    this.replyToMessage,
    this.callId,
    this.isFailed = false,
    this.isSending = false,
    this.reactions = const {},
  });

  /// Tiện lợi: lấy URL ảnh/media đầu tiên (hoặc null nếu không có)
  String? get firstMediaUrl => mediaUrls.isNotEmpty ? mediaUrls.first : null;

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    // Parse reactions từ joined data (list of {emoji, user_id})
    final Map<String, List<String>> parsedReactions = {};
    final rawReactions = json['reactions'];
    if (rawReactions is List) {
      for (final r in rawReactions) {
        final emoji = r['emoji'] as String?;
        final userId = r['user_id'] as String?;
        if (emoji != null && userId != null) {
          parsedReactions.putIfAbsent(emoji, () => []).add(userId);
        }
      }
    }

    // Parse media_urls: hỗ trợ cả định dạng mảng mới và string cũ (backward-compat)
    List<String> parsedMediaUrls = const [];
    final rawMediaUrls = json['media_urls'];
    final rawMediaUrl = json['media_url']; // backward-compat cột cũ
    if (rawMediaUrls is List) {
      parsedMediaUrls = rawMediaUrls.whereType<String>().toList();
    } else if (rawMediaUrls is String && rawMediaUrls.isNotEmpty) {
      // Trường hợp được decode từ JSON string (ObjectBox cache)
      try {
        final decoded = jsonDecode(rawMediaUrls);
        if (decoded is List) {
          parsedMediaUrls = decoded.whereType<String>().toList();
        }
      } catch (_) {
        parsedMediaUrls = [rawMediaUrls];
      }
    } else if (rawMediaUrl is String && rawMediaUrl.isNotEmpty) {
      // Backward-compat: cột media_url cũ dạng string đơn
      parsedMediaUrls = [rawMediaUrl];
    }

    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String?,
      mediaUrls: parsedMediaUrls,
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
      reactions: parsedReactions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'media_urls': mediaUrls,
      'message_type': messageType,
      'is_seen': isSeen,
      'created_at': createdAt.toUtc().toIso8601String(),
      'reply_to_message_id': replyToMessageId,
      'call_id': callId,
    };
  }

  bool get isText => messageType == 'text' || messageType.startsWith('vanish_text');
  bool get isImage => messageType == 'image' || messageType.startsWith('vanish_image');
  bool get isVoice => messageType == 'voice' || messageType.startsWith('vanish_voice');
  bool get isCall => messageType == 'call_log';
  bool get isRecalled => messageType == 'recalled';
  bool get isVanish => messageType.startsWith('vanish_');
  bool get isSystem => messageType == 'system';
  bool get hasReactions => reactions.isNotEmpty;

  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    List<String>? mediaUrls,
    String? messageType,
    bool? isSeen,
    DateTime? createdAt,
    String? replyToMessageId,
    MessageModel? replyToMessage,
    String? callId,
    bool? isFailed,
    bool? isSending,
    Map<String, List<String>>? reactions,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      messageType: messageType ?? this.messageType,
      isSeen: isSeen ?? this.isSeen,
      createdAt: createdAt ?? this.createdAt,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToMessage: replyToMessage ?? this.replyToMessage,
      callId: callId ?? this.callId,
      isFailed: isFailed ?? this.isFailed,
      isSending: isSending ?? this.isSending,
      reactions: reactions ?? this.reactions,
    );
  }
}
