import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/profile_model.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../feed/domain/post_model.dart';

class ProfileRepository {
  final SupabaseService _service;

  ProfileRepository(this._service);

  SupabaseClient get _client => _service.client;
  String? get currentUserId => _service.currentUserId;

  Future<ProfileModel> getProfile(String userId) async {
    final response = await _client
        .from(SupabaseConstants.profilesTable)
        .select('''
          *,
          posts_count:posts(count),
          followers_count:follows!follows_following_id_fkey(count),
          following_count:follows!follows_follower_id_fkey(count)
        ''')
        .eq('id', userId)
        .single();

    // Flatten counts from nested aggregates
    final json = Map<String, dynamic>.from(response);
    json['posts_count'] =
        (response['posts_count'] as List?)?.first?['count'] ?? 0;
    json['followers_count'] =
        (response['followers_count'] as List?)?.first?['count'] ?? 0;
    json['following_count'] =
        (response['following_count'] as List?)?.first?['count'] ?? 0;

    return ProfileModel.fromJson(json);
  }

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? username,
    String? bio,
    String? avatarUrl,
    String? coverUrl,
    List<String>? interests,
    bool? isPrivateProfile,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (username != null) updates['username'] = username;
    if (bio != null) updates['bio'] = bio;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (coverUrl != null) updates['cover_url'] = coverUrl;
    if (interests != null) updates['interests'] = interests;
    if (isPrivateProfile != null) updates['is_private_profile'] = isPrivateProfile;

    await _client
        .from(SupabaseConstants.profilesTable)
        .update(updates)
        .eq('id', userId);
  }

  // ── BLOCKING METHODS (Tất cả hướng về chat_blocks để chặn tin nhắn) ────────────────
  Future<void> blockUser(String targetUserId) async {
    await chatBlockUser(targetUserId);
  }

  Future<void> unblockUser(String targetUserId) async {
    await chatUnblockUser(targetUserId);
  }

  Future<List<ProfileModel>> getBlockedUsers() async {
    final currentId = currentUserId;
    if (currentId == null) return [];
    
    final response = await _client
        .from('chat_blocks')
        .select('blocked:profiles!chat_blocks_blocked_id_fkey(*)')
        .eq('blocker_id', currentId);
        
    final list = response as List;
    return list
        .map((e) => e['blocked'])
        .where((x) => x != null)
        .map((e) => ProfileModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // \u2500\u2500 CHAT BLOCKING METHODS (b\u1ea3ng chat_blocks \u2014 \u0111\u1ed9c l\u1eadp v\u1edbi blocks) \u2500\u2500\u2500\u2500\u2500\u2500\u2500
  Future<void> chatBlockUser(String targetUserId) async {
    final currentId = currentUserId;
    if (currentId == null) throw Exception('Not authenticated');
    await _client.from('chat_blocks').insert({
      'blocker_id': currentId,
      'blocked_id': targetUserId,
    });
  }

  Future<void> chatUnblockUser(String targetUserId) async {
    final currentId = currentUserId;
    if (currentId == null) throw Exception('Not authenticated');
    await _client
        .from('chat_blocks')
        .delete()
        .eq('blocker_id', currentId)
        .eq('blocked_id', targetUserId);
  }

  /// Danh s\u00e1ch ng\u01b0\u1eddi m\u00ecnh \u0111\u00e3 ch\u1eb7n tin nh\u1eafn.
  Future<List<String>> getChatBlockedUserIds() async {
    final currentId = currentUserId;
    if (currentId == null) return [];
    final response = await _client
        .from('chat_blocks')
        .select('blocked_id')
        .eq('blocker_id', currentId);
    return (response as List).map((e) => e['blocked_id'] as String).toList();
  }

  /// Ki\u1ec3m tra xem [targetUserId] c\u00f3 \u0111ang ch\u1eb7n tin nh\u1eafn c\u1ee7a m\u00ecnh kh\u00f4ng (chi\u1ec1u ng\u01b0\u1ee3c).
  Future<bool> isChatBlockedByUser(String targetUserId) async {
    final currentId = currentUserId;
    if (currentId == null) return false;
    final response = await _client
        .from('chat_blocks')
        .select('blocker_id')
        .eq('blocker_id', targetUserId)
        .eq('blocked_id', currentId)
        .limit(1);
    return (response as List).isNotEmpty;
  }

  // ── MUTING METHODS ─────────────────────────────────────────────────────────
  Future<void> muteUser(String targetUserId) async {
    final currentId = currentUserId;
    if (currentId == null) throw Exception('Not authenticated');
    await _client.from('mutes').insert({
      'muter_id': currentId,
      'muted_id': targetUserId,
    });
  }

  Future<void> unmuteUser(String targetUserId) async {
    final currentId = currentUserId;
    if (currentId == null) throw Exception('Not authenticated');
    await _client
        .from('mutes')
        .delete()
        .eq('muter_id', currentId)
        .eq('muted_id', targetUserId);
  }

  Future<List<ProfileModel>> getMutedUsers() async {
    final currentId = currentUserId;
    if (currentId == null) return [];
    
    final response = await _client
        .from('mutes')
        .select('muted:profiles!mutes_muted_id_fkey(*)')
        .eq('muter_id', currentId);
        
    final list = response as List;
    return list
        .map((e) => e['muted'])
        .where((x) => x != null)
        .map((e) => ProfileModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<String> uploadAvatar(String userId, XFile file) async {
    final path = '$userId/avatar.jpg';
    return _service.uploadFile(
      bucket: SupabaseConstants.avatarsBucket,
      path: path,
      file: file,
      upsert: true,
    );
  }

  Future<String> uploadCover(String userId, XFile file) async {
    final path = '$userId/cover.jpg';
    return _service.uploadFile(
      bucket: SupabaseConstants.coversBucket,
      path: path,
      file: file,
      upsert: true,
    );
  }

  Future<List<PostModel>> getUserPosts(String userId) async {
    final data = await _client
        .from(SupabaseConstants.postsTable)
        .select('*, profiles(*), post_media(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final postsList = data as List;
    if (postsList.isEmpty) return [];

    final currentId = currentUserId;
    if (currentId == null) {
      return postsList.map((e) => PostModel.fromJson(e)).toList();
    }

    // Fetch likes for these posts by current user
    final postIds = postsList.map((e) => e['id']).toList();
    Set<String> likedPostIds = {};
    try {
      final likedPostsData = await _client
          .from(SupabaseConstants.likesTable)
          .select('post_id')
          .eq('user_id', currentId)
          .inFilter('post_id', postIds);

      likedPostIds = (likedPostsData as List).map((e) => e['post_id'] as String).toSet();
    } catch (e) {
      print('Warning: Failed to fetch user profile post likes: $e');
    }

    return postsList.map((e) {
      return PostModel.fromJson(e, isLiked: likedPostIds.contains(e['id']));
    }).toList();
  }
}
