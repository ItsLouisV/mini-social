import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';

class SocialRepository {
  final SupabaseClient _client;

  SocialRepository(this._client);

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<bool> isFollowing(String targetUserId) async {
    final data = await _client
        .from(SupabaseConstants.followsTable)
        .select('id')
        .eq('follower_id', currentUserId!)
        .eq('following_id', targetUserId)
        .maybeSingle();
    return data != null;
  }

  Future<void> follow(String targetUserId) async {
    await _client.from(SupabaseConstants.followsTable).insert({
      'follower_id': currentUserId,
      'following_id': targetUserId,
    });
  }

  Future<void> unfollow(String targetUserId) async {
    await _client
        .from(SupabaseConstants.followsTable)
        .delete()
        .eq('follower_id', currentUserId!)
        .eq('following_id', targetUserId);
  }

  // Notifications
  Stream<List<Map<String, dynamic>>> watchNotifications() {
    return _client
        .from(SupabaseConstants.notificationsTable)
        .stream(primaryKey: ['id'])
        .eq('receiver_id', currentUserId!)
        .order('created_at', ascending: false)
        .limit(50);
  }

  Future<void> markAllAsRead() async {
    await _client
        .from(SupabaseConstants.notificationsTable)
        .update({'is_read': true})
        .eq('receiver_id', currentUserId!)
        .eq('is_read', false);
  }

  Future<int> getUnreadCount() async {
    final data = await _client
        .from(SupabaseConstants.notificationsTable)
        .select('id')
        .eq('receiver_id', currentUserId!)
        .eq('is_read', false);
    return (data as List).length;
  }
}
