import 'package:isar/isar.dart';
import 'isar_message.dart';

part 'isar_post.g.dart';

@collection
class IsarPost {
  Id get isarId => fastHash(id);

  @Index(unique: true, replace: true)
  final String id;

  @Index()
  final String authorId;

  final String? authorName;
  final String? authorAvatar;
  final String content;
  final List<String> imageUrls;
  final String? videoUrl;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final DateTime createdAt;
  final DateTime updatedAt;

  IsarPost({
    required this.id,
    required this.authorId,
    this.authorName,
    this.authorAvatar,
    required this.content,
    this.imageUrls = const [],
    this.videoUrl,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    required this.createdAt,
    required this.updatedAt,
  });
}
