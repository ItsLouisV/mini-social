import 'package:isar/isar.dart';
import 'isar_message.dart';

part 'isar_post_draft.g.dart';

@collection
class IsarPostDraft {
  Id get isarId => fastHash(id);

  @Index(unique: true, replace: true)
  final String id;

  final String content;
  final List<String> localMediaPaths;
  final DateTime updatedAt;

  IsarPostDraft({
    required this.id,
    required this.content,
    this.localMediaPaths = const [],
    required this.updatedAt,
  });
}
