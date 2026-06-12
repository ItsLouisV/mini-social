import 'package:objectbox/objectbox.dart';

@Entity()
class CachedProfile {
  @Id()
  int obxId = 0;

  /// UUID từ Supabase
  @Unique(onConflict: ConflictStrategy.replace)
  late String id;

  late String username;
  String? fullName;
  String? avatarUrl;
  String? coverUrl;
  late String createdAt;
  late String syncedAt;
}
