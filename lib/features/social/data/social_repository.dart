import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/supabase_service.dart';

class SocialRepository {
  final SupabaseService _service;

  SocialRepository(this._service);

  SupabaseClient get _client => _service.client;

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

  Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    final data = await _client
        .from(SupabaseConstants.followsTable)
        .select('profiles!follows_follower_id_fkey(*)')
        .eq('following_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data.map((x) => x['profiles']));
  }

  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    final data = await _client
        .from(SupabaseConstants.followsTable)
        .select('profiles!follows_following_id_fkey(*)')
        .eq('follower_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data.map((x) => x['profiles']));
  }

  // Notifications
  Stream<List<Map<String, dynamic>>> watchNotifications() async* {
    try {
      final initialData = await _getNotificationsWithProfiles();
      yield initialData;
    } catch (e) {
      print('Error fetching initial notifications: $e');
      rethrow;
    }

    final notificationsStream = _client
        .from(SupabaseConstants.notificationsTable)
        .stream(primaryKey: ['id'])
        .eq('receiver_id', currentUserId!)
        .order('created_at', ascending: false)
        .limit(50)
        .asyncMap((_) => _getNotificationsWithProfiles())
        .handleError((err) {
          print('Supabase watchNotifications stream error: $err');
          _service.handleAuthError(err);
        });

    try {
      await for (final notifications in notificationsStream) {
        yield notifications;
      }
    } catch (e) {
      print('Supabase watchNotifications main stream error: $e');
    }
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

  Future<void> markNotificationAsRead(String notificationId) async {
    await _client
        .from(SupabaseConstants.notificationsTable)
        .update({'is_read': true})
        .eq('id', notificationId)
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

  Future<String?> getFriendStatus(String targetUserId) async {
    final myId = currentUserId;
    if (myId == null || myId == targetUserId) return null;

    try {
      final data = await _client
          .from('friend_requests')
          .select('sender_id, receiver_id, status')
          .or('and(sender_id.eq.$myId,receiver_id.eq.$targetUserId),and(sender_id.eq.$targetUserId,receiver_id.eq.$myId)')
          .maybeSingle();
      
      if (data == null) return null;
      final status = data['status'] as String;
      final senderId = data['sender_id'] as String;
      
      if (status == 'accepted') {
        return 'accepted';
      } else if (status == 'pending') {
        if (senderId == myId) {
          return 'pending_sent';
        } else {
          return 'pending_received';
        }
      }
      return null;
    } catch (e) {
      print('Error getting friend status: $e');
      return null;
    }
  }

  Future<void> sendFriendRequest(String targetUserId) async {
    await _client.from('friend_requests').insert({
      'sender_id': currentUserId,
      'receiver_id': targetUserId,
      'status': 'pending',
    });
  }

  Future<void> acceptFriendRequest(String targetUserId) async {
    await _client
        .from('friend_requests')
        .update({'status': 'accepted'})
        .eq('sender_id', targetUserId)
        .eq('receiver_id', currentUserId!);
  }

  Future<void> cancelFriendRequest(String targetUserId) async {
    await _client
        .from('friend_requests')
        .delete()
        .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$targetUserId),and(sender_id.eq.$targetUserId,receiver_id.eq.$currentUserId)');
  }

  Future<List<Map<String, dynamic>>> getFriends() async {
    final userId = currentUserId;
    if (userId == null) return [];
    
    final data = await _client
        .from('friend_requests')
        .select('sender_id, receiver_id')
        .eq('status', 'accepted')
        .or('sender_id.eq.$userId,receiver_id.eq.$userId');
        
    final friendIds = (data as List).map((x) {
      if (x['sender_id'] == userId) {
        return x['receiver_id'] as String;
      } else {
        return x['sender_id'] as String;
      }
    }).toList();
    
    if (friendIds.isEmpty) return [];
    
    final profilesData = await _client
        .from(SupabaseConstants.profilesTable)
        .select('*')
        .inFilter('id', friendIds);
        
    return List<Map<String, dynamic>>.from(profilesData);
  }

  Future<List<Map<String, dynamic>>> getPendingReceived() async {
    final userId = currentUserId;
    if (userId == null) return [];
    
    final data = await _client
        .from('friend_requests')
        .select('sender_id')
        .eq('receiver_id', userId)
        .eq('status', 'pending');
        
    final senderIds = (data as List).map((x) => x['sender_id'] as String).toList();
    if (senderIds.isEmpty) return [];
    
    final profilesData = await _client
        .from(SupabaseConstants.profilesTable)
        .select('*')
        .inFilter('id', senderIds);
        
    return List<Map<String, dynamic>>.from(profilesData);
  }

  Future<List<Map<String, dynamic>>> getPendingSent() async {
    final userId = currentUserId;
    if (userId == null) return [];
    
    final data = await _client
        .from('friend_requests')
        .select('receiver_id')
        .eq('sender_id', userId)
        .eq('status', 'pending');
        
    final receiverIds = (data as List).map((x) => x['receiver_id'] as String).toList();
    if (receiverIds.isEmpty) return [];
    
    final profilesData = await _client
        .from(SupabaseConstants.profilesTable)
        .select('*')
        .inFilter('id', receiverIds);
        
    return List<Map<String, dynamic>>.from(profilesData);
  }
}
