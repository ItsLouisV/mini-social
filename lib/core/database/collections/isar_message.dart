import 'package:isar/isar.dart';

part 'isar_message.g.dart';

int fastHash(String string) {
  return string.hashCode.abs();
}

@collection
class IsarMessage {
  Id get isarId => fastHash(id);

  @Index(unique: true, replace: true)
  final String id;

  @Index()
  final String conversationId;

  final String senderId;
  final String content;
  final String messageType; // text, image, video, voice, file, system
  final DateTime createdAt;

  final String? replyToMessageId;
  final String? status; // sending, sent, error

  // Media Metadata
  final int? mediaWidth;
  final int? mediaHeight;
  final int? mediaDuration; // seconds
  final String? waveform;
  final String? mediaUrlsJson; // JSON-encoded list of media URLs

  final DateTime updatedAt;
  final bool isDeleted;

  IsarMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    required this.createdAt,
    this.replyToMessageId,
    this.status = 'sent',
    this.mediaWidth,
    this.mediaHeight,
    this.mediaDuration,
    this.waveform,
    this.mediaUrlsJson,
    required this.updatedAt,
    this.isDeleted = false,
  });
}
