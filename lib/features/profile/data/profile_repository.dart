import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/profile_model.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../feed/domain/post_model.dart';

class UserPostsData {
  final List<PostModel> posts;
  final int totalRawPosts;
  final int hiddenFriendsPostsCount;
  final bool isFriendOrFollower;

  const UserPostsData({
    required this.posts,
    required this.totalRawPosts,
    this.hiddenFriendsPostsCount = 0,
    this.isFriendOrFollower = false,
  });
}

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

    // Tự động đồng bộ ảnh đại diện & tên từ OAuth (Google) vào bảng profiles nếu chưa có
    final currentUser = _client.auth.currentUser;
    if (currentUser != null && currentUser.id == userId) {
      final meta = currentUser.userMetadata;
      if (meta != null) {
        final googleAvatar = (meta['avatar_url'] ?? meta['picture']) as String?;
        final googleName = (meta['full_name'] ?? meta['name']) as String?;
        final currentAvatar = json['avatar_url'] as String?;
        final currentFullName = json['full_name'] as String?;

        final updates = <String, dynamic>{};
        if ((currentAvatar == null || currentAvatar.isEmpty) &&
            googleAvatar != null &&
            googleAvatar.isNotEmpty) {
          updates['avatar_url'] = googleAvatar;
          json['avatar_url'] = googleAvatar;
        }
        if ((currentFullName == null || currentFullName.isEmpty) &&
            googleName != null &&
            googleName.isNotEmpty) {
          updates['full_name'] = googleName;
          json['full_name'] = googleName;
        }

        if (updates.isNotEmpty) {
          Future(() async {
            try {
              await _client
                  .from(SupabaseConstants.profilesTable)
                  .update(updates)
                  .eq('id', userId);
            } catch (e) {
              debugPrint('Error syncing OAuth profile data: $e');
            }
          });
        }
      }
    }

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

  // ── CHAT BLOCKING METHODS (bảng chat_blocks — độc lập với blocks) ───────
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

  /// Danh sách người mình đã chặn tin nhắn.
  Future<List<String>> getChatBlockedUserIds() async {
    final currentId = currentUserId;
    if (currentId == null) return [];
    final response = await _client
        .from('chat_blocks')
        .select('blocked_id')
        .eq('blocker_id', currentId);
    return (response as List).map((e) => e['blocked_id'] as String).toList();
  }

  /// Kiểm tra xem [targetUserId] có đang chặn tin nhắn của mình không (chiều ngược).
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

  Future<UserPostsData> getUserPosts(String userId) async {
    final currentId = currentUserId;

    // 1. Lấy tất cả bài của userId, lọc bài đã xóa (soft delete)
    final data = await _client
        .from(SupabaseConstants.postsTable)
        .select('*, profiles(*), post_media(*)')
        .eq('user_id', userId)
        .isFilter('deleted_at', null) // Bỏ bài đã chuyển vào thùng rác
        .order('created_at', ascending: false);

    final postsList = data as List;
    if (postsList.isEmpty) {
      return const UserPostsData(
        posts: [],
        totalRawPosts: 0,
      );
    }

    // 2. Lọc theo quyền riêng tư (privacy)
    List filteredPostsJson;
    int hiddenFriendsCount = 0;
    bool isFriendOrFollower = false;

    if (currentId == null) {
      // Chưa đăng nhập: chỉ xem bài public
      filteredPostsJson = postsList.where((p) => (p['privacy'] as String? ?? 'public') == 'public').toList();
    } else if (currentId == userId) {
      // Chính chủ: xem tất cả bài viết của bản thân
      filteredPostsJson = postsList;
      isFriendOrFollower = true;
    } else {
      // Người khác: kiểm tra quan hệ bạn bè hoặc đang theo dõi
      try {
        final friendData = await _client
            .from('friend_requests')
            .select('sender_id, receiver_id')
            .eq('status', 'accepted')
            .or('sender_id.eq.$currentId,receiver_id.eq.$currentId');

        final isFriend = (friendData as List).any((row) =>
            (row['sender_id'] == currentId && row['receiver_id'] == userId) ||
            (row['sender_id'] == userId && row['receiver_id'] == currentId));

        final followData = await _client
            .from(SupabaseConstants.followsTable)
            .select('id')
            .eq('follower_id', currentId)
            .eq('following_id', userId)
            .maybeSingle();

        final isFollowing = followData != null;
        isFriendOrFollower = isFriend || isFollowing;
      } catch (e) {
        debugPrint('Warning checking friend/follower status: $e');
      }

      filteredPostsJson = postsList.where((p) {
        final privacy = (p['privacy'] as String? ?? 'public').toLowerCase();

        // Riêng tư (private / only_me) -> TUYỆT ĐỐI KHÔNG HIỂN THỊ CHO NGƯỜI KHÁC
        if (privacy == 'private' || privacy == 'only_me') {
          return false;
        }

        // Bạn bè / Người theo dõi (friends / followers)
        if (privacy == 'friends' || privacy == 'followers') {
          if (isFriendOrFollower) {
            return true;
          } else {
            hiddenFriendsCount++;
            return false;
          }
        }

        // Công khai (public)
        return true;
      }).toList();
    }

    if (filteredPostsJson.isEmpty) {
      return UserPostsData(
        posts: [],
        totalRawPosts: postsList.length,
        hiddenFriendsPostsCount: hiddenFriendsCount,
        isFriendOrFollower: isFriendOrFollower,
      );
    }

    // 3. Lấy danh sách bài đã thích của người dùng hiện tại
    Set<String> likedPostIds = {};
    if (currentId != null) {
      try {
        final postIds = filteredPostsJson.map((e) => e['id']).toList();
        final likedPostsData = await _client
            .from(SupabaseConstants.likesTable)
            .select('post_id')
            .eq('user_id', currentId)
            .inFilter('post_id', postIds);
        likedPostIds = (likedPostsData as List)
            .map((e) => e['post_id'] as String)
            .toSet();
      } catch (e) {
        debugPrint('Warning: Failed to fetch profile post likes: $e');
      }
    }

    final posts = filteredPostsJson.map((e) {
      return PostModel.fromJson(e, isLiked: likedPostIds.contains(e['id']));
    }).toList();

    return UserPostsData(
      posts: posts,
      totalRawPosts: postsList.length,
      hiddenFriendsPostsCount: hiddenFriendsCount,
      isFriendOrFollower: isFriendOrFollower,
    );
  }
}
