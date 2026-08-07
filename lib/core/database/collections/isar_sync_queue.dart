import 'package:isar/isar.dart';
import 'isar_message.dart';

part 'isar_sync_queue.g.dart';

@collection
class IsarSyncQueue {
  Id get isarId => fastHash(id);

  @Index(unique: true, replace: true)
  final String id;

  final String actionType; // sendMessage, createPost, likePost, deleteMessage, etc.
  final String payloadJson;
  final DateTime createdAt;
  final int retryCount;

  IsarSyncQueue({
    required this.id,
    required this.actionType,
    required this.payloadJson,
    required this.createdAt,
    this.retryCount = 0,
  });
}
