import 'package:objectbox/objectbox.dart';

/// Tin nhắn gửi thất bại — lưu lại để hiển thị UI (!) và cho phép retry.
@Entity()
class FailedMessage {
  @Id()
  int obxId = 0;

  /// UUID sinh client-side
  @Unique(onConflict: ConflictStrategy.replace)
  late String localId;

  @Index()
  late String conversationId;

  late String senderId;
  String? content;
  String? mediaUrl;
  String messageType = 'text';
  String? replyToMessageId;
  late String createdAt;

  // Reply-to message data (denormalized cho display)
  String? replyContent;
  String? replySenderId;
}
