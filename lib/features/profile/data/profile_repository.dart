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
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (username != null) updates['username'] = username;
    if (bio != null) updates['bio'] = bio;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (coverUrl != null) updates['cover_url'] = coverUrl;

    await _client
        .from(SupabaseConstants.profilesTable)
        .update(updates)
        .eq('id', userId);
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
