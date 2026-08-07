import 'package:isar/isar.dart';
import 'isar_message.dart';

part 'isar_conversation.g.dart';

@collection
class IsarConversation {
  Id get isarId => fastHash(id);

  @Index(unique: true, replace: true)
  final String id;

  final String type; // direct, group
  final String? name;
  final String? avatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final bool isHidden;
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserAvatar;
  final DateTime updatedAt;

  IsarConversation({
    required this.id,
    this.type = 'direct',
    this.name,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.isHidden = false,
    this.otherUserId,
    this.otherUserName,
    this.otherUserAvatar,
    required this.updatedAt,
  });
}
