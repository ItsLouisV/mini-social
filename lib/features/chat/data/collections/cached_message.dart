import 'package:objectbox/objectbox.dart';

@Entity()
class CachedMessage {
  @Id()
  int obxId = 0;

  /// UUID từ Supabase
  @Unique(onConflict: ConflictStrategy.replace)
  late String id;

  @Index()
  late String conversationId;

  late String senderId;
  String? content;
  String? mediaUrl;
  String messageType = 'text';
  bool isSeen = false;
  String? replyToMessageId;
  String? callId;
  late String createdAt;
  late String syncedAt;

  // Reply-to message data (denormalized để không cần join)
  String? replyContent;
  String? replySenderId;
  String? replyMessageType;
}
