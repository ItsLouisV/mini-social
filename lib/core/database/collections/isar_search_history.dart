import 'package:isar/isar.dart';
import 'isar_message.dart';

part 'isar_search_history.g.dart';

@collection
class IsarSearchHistory {
  Id get isarId => fastHash(id);

  @Index(unique: true, replace: true)
  final String id;

  @Index()
  final String query;

  final DateTime timestamp;

  IsarSearchHistory({
    required this.id,
    required this.query,
    required this.timestamp,
  });
}
