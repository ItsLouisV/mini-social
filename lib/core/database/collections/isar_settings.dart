import 'package:isar/isar.dart';
import 'isar_message.dart';

part 'isar_settings.g.dart';

@collection
class IsarSettings {
  Id get isarId => fastHash(key);

  @Index(unique: true, replace: true)
  final String key;

  final String value;

  IsarSettings({
    required this.key,
    required this.value,
  });
}
