import 'package:isar/isar.dart';
import 'isar_message.dart';

part 'isar_notification.g.dart';

@collection
class IsarNotification {
  Id get isarId => fastHash(id);

  @Index(unique: true, replace: true)
  final String id;

  @Index()
  final String receiverId;

  final String senderId;
  final String? senderName;
  final String? senderAvatar;
  final String type;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  IsarNotification({
    required this.id,
    required this.receiverId,
    required this.senderId,
    this.senderName,
    this.senderAvatar,
    required this.type,
    required this.content,
    this.isRead = false,
    required this.createdAt,
  });
}
