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
    // Use notifications stream as trigger, then fetch with profile join
    return _client
        .from(SupabaseConstants.notificationsTable)
        .stream(primaryKey: ['id'])
        .eq('receiver_id', currentUserId!)
        .order('created_at', ascending: false)
        .limit(50)
        .asyncMap((_) => _getNotificationsWithProfiles());
  }

  Future<List<Map<String, dynamic>>> _getNotificationsWithProfiles() async {
    final data = await _client
        .from(SupabaseConstants.notificationsTable)
        .select('*, profiles!notifications_sender_id_fkey(id, full_name, username, avatar_url)')
        .eq('receiver_id', currentUserId!)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(data as List);
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
