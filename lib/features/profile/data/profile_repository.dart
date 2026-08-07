import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/profile_model.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../feed/domain/post_model.dart';

import '../../../core/services/isar_service.dart';
import '../../../core/database/collections/isar_profile.dart';

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
  final IsarService? _isarService;

  ProfileRepository(this._service, [this._isarService]);

  SupabaseClient get _client => _service.client;
  String? get currentUserId => _service.currentUserId;

  Future<ProfileModel> getProfile(String userId) async {
    try {
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

      final json = Map<String, dynamic>.from(response);
      json['posts_count'] =
          (response['posts_count'] as List?)?.first?['count'] ?? 0;
      json['followers_count'] =
          (response['followers_count'] as List?)?.first?['count'] ?? 0;
      json['following_count'] =
          (response['following_count'] as List?)?.first?['count'] ?? 0;

      final model = ProfileModel.fromJson(json);

      // Cache to Isar
      if (_isarService?.isar != null) {
        await _isarService!.isar!.writeTxn(() async {
          await _isarService!.isar!.isarProfiles.put(IsarProfile(
            id: model.id,
            username: model.username,
            fullName: model.fullName,
            avatarUrl: model.avatarUrl,
            bio: model.bio,
            followerCount: model.followersCount,
            followingCount: model.followingCount,
            updatedAt: DateTime.now().toUtc(),
          ));
        });
      }

      if (_isarService?.webService != null) {
        await _isarService!.webService!.saveProfile(model.toJson());
      }

      return model;
    } catch (e) {
      debugPrint('⚠️ [ProfileRepository] Offline fallback for profile: $e');
      if (_isarService?.isar != null) {
        final cached = await _isarService!.isar!.isarProfiles
            .filter()
            .idEqualTo(userId)
            .findFirst();
        if (cached != null) {
          return ProfileModel(
            id: cached.id,
            username: cached.username,
            fullName: cached.fullName,
            avatarUrl: cached.avatarUrl,
            bio: cached.bio,
            followersCount: cached.followerCount,
            followingCount: cached.followingCount,
            createdAt: DateTime.now(),
          );
        }
      } else if (_isarService?.webService != null) {
        final cached = _isarService!.webService!.getProfile(userId);
        if (cached != null) {
          return ProfileModel.fromJson(cached);
        }
      }
      rethrow;
    }
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
      // Chưa đăng nhập: chỉ xem bài public và đã published
      filteredPostsJson = postsList.where((p) {
        final status = p['moderation_status'] as String? ?? 'pending';
        final privacy = p['privacy'] as String? ?? 'public';
        return status == 'published' && privacy == 'public';
      }).toList();
    } else if (currentId == userId) {
      // // Chính chủ: xem bài của bản thân (loại bài hidden/removed do vi phạm)
      // filteredPostsJson = postsList.where((p) {
      //   final status = p['moderation_status'] as String? ?? 'pending';
      //   return status != 'hidden' && status != 'removed';
      // }).toList();


      // Chính chủ: xem tất cả bài viết của bản thân trong profile (kể cả hidden / removed / pending)
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
        final status = p['moderation_status'] as String? ?? 'pending';
        // Người khác chỉ thấy bài published
        if (status != 'published') return false;

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
