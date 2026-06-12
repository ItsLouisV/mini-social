import 'package:objectbox/objectbox.dart';

@Entity()
class CachedConversation {
  @Id()
  int obxId = 0;

  /// UUID từ Supabase — unique index để upsert
  @Unique(onConflict: ConflictStrategy.replace)
  late String id;

  late String participant1;
  late String participant2;

  String? lastMessage;
  String? lastMessageAt;
  String? lastMessageSenderId;

  int p1UnreadCount = 0;
  int p2UnreadCount = 0;

  bool p1IsPinned = false;
  bool p2IsPinned = false;
  bool p1IsHidden = false;
  bool p2IsHidden = false;

  late String createdAt;

  /// Thời điểm sync cuối cùng từ Supabase
  late String syncedAt;
}
