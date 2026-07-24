import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:async/async.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/comment_model.dart';
import '../domain/post_model.dart';
import '../../../core/constants/supabase_constants.dart';

class PostRepository {
  final SupabaseService _service;
  final _uuid = const Uuid();

  PostRepository(this._service);

  SupabaseClient get _client => _service.client;
  String? get currentUserId => _service.currentUserId;

  // ── Feed ──
  Future<List<PostModel>> getFeedPosts(
      {int page = 0, int pageSize = 20}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    // Fetch all posts from Supabase first
    final data = await _client
        .from(SupabaseConstants.postsTable)
        .select('*, profiles(*), post_media(*)')
        .filter('deleted_at', 'is', null)
        .order('created_at', ascending: false);

    final postsList = data as List;
    if (postsList.isEmpty) return [];

    final userId = currentUserId;
    if (userId == null) {
      return postsList.map((e) => PostModel.fromJson(e)).toList();
    }

    // 1. Get the current user's follows
    Set<String> followingIds = {};
    try {
      final followingData = await _client
          .from(SupabaseConstants.followsTable)
          .select('following_id')
          .eq('follower_id', userId);
      followingIds = (followingData as List).map((x) => x['following_id'] as String).toSet();
    } catch (e) {
      print('Warning: Failed to fetch following: $e');
    }

    // 2. Get the current user's friends (accepted friend requests)
    Set<String> friendIds = {};
    try {
      final friendsData = await _client
          .from('friend_requests')
          .select('sender_id, receiver_id')
          .eq('status', 'accepted')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId');
      friendIds = (friendsData as List).map((x) {
        if (x['sender_id'] == userId) {
          return x['receiver_id'] as String;
        } else {
          return x['sender_id'] as String;
        }
      }).toSet();
    } catch (e) {
      print('Warning: Failed to fetch friends: $e');
    }

    // 3. Filter posts based on privacy settings
    final filteredPostsList = postsList.where((postJson) {
      final postUserId = postJson['user_id'] as String;
      if (postUserId == userId) return true; // Creator always sees their own posts

      final privacy = postJson['privacy'] as String? ?? 'public';
      if (privacy == 'public') return true;
      if (privacy == 'private') return false; // Private is creator-only
      if (privacy == 'friends') {
        return friendIds.contains(postUserId);
      }
      if (privacy == 'followers') {
        return followingIds.contains(postUserId);
      }
      return true;
    }).toList();

    // 4. Apply pagination range in-memory
    if (from >= filteredPostsList.length) return [];
    final paginatedList = filteredPostsList.sublist(
      from,
      (to + 1) > filteredPostsList.length ? filteredPostsList.length : (to + 1),
    );

    // Fetch likes for these posts by current user
    final postIds = paginatedList.map((e) => e['id']).toList();
    Set<String> likedPostIds = {};
    try {
      final likedPostsData = await _client
          .from(SupabaseConstants.likesTable)
          .select('post_id')
          .eq('user_id', userId)
          .inFilter('post_id', postIds);

      likedPostIds = (likedPostsData as List).map((e) => e['post_id'] as String).toSet();
    } catch (e) {
      print('Warning: Failed to fetch post likes: $e');
    }

    return paginatedList.map((e) {
      return PostModel.fromJson(e, isLiked: likedPostIds.contains(e['id']));
    }).toList();
  }

  Future<bool> _isFriend(String userId1, String userId2) async {
    try {
      final data = await _client
          .from('friend_requests')
          .select('id')
          .eq('status', 'accepted')
          .or('and(sender_id.eq.$userId1,receiver_id.eq.$userId2),and(sender_id.eq.$userId2,receiver_id.eq.$userId1)')
          .maybeSingle();
      return data != null;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isFollowing(String followerId, String followingId) async {
    try {
      final data = await _client
          .from(SupabaseConstants.followsTable)
          .select('id')
          .eq('follower_id', followerId)
          .eq('following_id', followingId)
          .maybeSingle();
      return data != null;
    } catch (e) {
      return false;
    }
  }

  Stream<List<PostModel>> watchPosts() async* {
    try {
      final initialData = await getFeedPosts();
      yield initialData;
    } catch (e) {
      print('Error fetching initial posts in watchPosts: $e');
      rethrow;
    }

    final postsStream = _client
        .from(SupabaseConstants.postsTable)
        .stream(primaryKey: ['id'])
        .handleError((err) {
          print('Supabase watchPosts stream error (posts): $err');
          _service.handleAuthError(err);
        });
    final likesStream = _client
        .from(SupabaseConstants.likesTable)
        .stream(primaryKey: ['id'])
        .handleError((err) {
          print('Supabase watchPosts stream error (likes): $err');
          _service.handleAuthError(err);
        });
    final commentsStream = _client
        .from(SupabaseConstants.commentsTable)
        .stream(primaryKey: ['id'])
        .handleError((err) {
          print('Supabase watchPosts stream error (comments): $err');
          _service.handleAuthError(err);
        });

    final combinedStream = StreamGroup.merge([postsStream, likesStream, commentsStream])
        .asyncMap((_) => getFeedPosts())
        .handleError((err) {
          print('Supabase watchPosts combined stream error: $err');
          _service.handleAuthError(err);
        });

    try {
      await for (final posts in combinedStream) {
        yield posts;
      }
    } catch (e) {
      print('Supabase watchPosts main stream error: $e');
    }
  }

  // ── Create Post ──
  Future<PostModel> createPost({
    required String caption,
    required List<XFile> media,
    String privacy = 'public',
    String layoutType = 'grid',
    String? postId,
  }) async {
    final userId = currentUserId!;
    final finalPostId = postId ?? _uuid.v4();

    final finalCaption = media.length >= 3
        ? (caption != null && caption.trim().isNotEmpty
            ? '${caption.trim()}\n[layout:$layoutType]'
            : '[layout:$layoutType]')
        : caption;

    // 1. Insert post first
    final insertData = <String, dynamic>{
      'id': finalPostId,
      'user_id': userId,
      'caption': finalCaption,
      'privacy': privacy,
    };

    try {
      insertData['layout_type'] = layoutType;
      await _client.from(SupabaseConstants.postsTable).insert(insertData);
    } catch (_) {
      insertData.remove('layout_type');
      await _client.from(SupabaseConstants.postsTable).insert(insertData);
    }

    // 2. Upload media and insert media records
    for (int i = 0; i < media.length; i++) {
      final item = media[i];
      final mediaId = _uuid.v4();
      
      final extension = item.name.split('.').last.toLowerCase();
      final isVideo = ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(extension);
      final fileExtension = isVideo ? extension : 'jpg';
      final path = '$userId/$finalPostId/$i.$fileExtension';
      final mediaType = isVideo ? 'video' : 'image';
      
      final url = await _service.uploadFile(
        bucket: SupabaseConstants.postsBucket,
        path: path,
        file: item,
      );

      int? width;
      int? height;
      double? aspectRatio;

      if (!isVideo) {
        try {
          final bytes = await item.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          width = frame.image.width;
          height = frame.image.height;
          if (height > 0) {
            aspectRatio = double.parse((width / height).toStringAsFixed(4));
          }
        } catch (e) {
          print('Error extracting image metadata: $e');
        }
      }

      final mediaInsertData = <String, dynamic>{
        'id': mediaId,
        'post_id': finalPostId,
        'url': url,
        'path': path,
        'type': mediaType,
        'order_index': i,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (aspectRatio != null) 'aspect_ratio': aspectRatio,
        'thumbnail_url': isVideo ? null : url,
      };

      try {
        await _client.from(SupabaseConstants.postMediaTable).insert(mediaInsertData);
      } catch (_) {
        await _client.from(SupabaseConstants.postMediaTable).insert({
          'id': mediaId,
          'post_id': finalPostId,
          'url': url,
          'type': mediaType,
          'order_index': i,
        });
      }
    }

    // 3. Fetch the complete post
    return getPost(finalPostId);
  }

  // ── Delete Post ──
  Future<void> deletePost(String postId) async {
    // 1. Lấy danh sách media trước khi xóa
    try {
      final mediaRows = await _client
          .from(SupabaseConstants.postMediaTable)
          .select('url, path')
          .eq('post_id', postId);

      final paths = <String>[];
      for (final m in mediaRows as List) {
        final p = m['path'] as String?;
        final u = m['url'] as String?;
        if (p != null && p.isNotEmpty) {
          paths.add(p);
        } else if (u != null && u.contains('/posts/')) {
          paths.add(u.split('/posts/').last);
        }
      }

      // 2. Xóa file thực tế trên Storage qua SDK (không qua SQL)
      if (paths.isNotEmpty) {
        await _client.storage.from(SupabaseConstants.postsBucket).remove(paths);
      }
    } catch (e) {
      debugPrint('Warning: Could not delete storage files for post $postId: $e');
    }

    // 3. Xóa bản ghi post khỏi Database (post_media sẽ bị cascade delete)
    await _client.from(SupabaseConstants.postsTable).delete().eq('id', postId);
  }

  // ── Get Single Post ──
  Future<PostModel> getPost(String postId) async {
    final data = await _client
        .from(SupabaseConstants.postsTable)
        .select('*, profiles(*), post_media(*)')
        .eq('id', postId)
        .single();
    
    final userId = currentUserId;
    final postUserId = data['user_id'] as String;
    final privacy = data['privacy'] as String? ?? 'public';
    if (userId != null && postUserId != userId) {
      if (privacy == 'private') {
        throw Exception('Bài viết này là riêng tư.');
      }
      if (privacy == 'friends') {
        final isFriend = await _isFriend(userId, postUserId);
        if (!isFriend) throw Exception('Bài viết này chỉ dành cho bạn bè.');
      }
      if (privacy == 'followers') {
        final following = await _isFollowing(userId, postUserId);
        if (!following) throw Exception('Bài viết này chỉ dành cho người theo dõi.');
      }
    }

    bool isLiked = false;
    if (userId != null) {
      try {
        final likedData = await _client
            .from(SupabaseConstants.likesTable)
            .select('id')
            .eq('post_id', postId)
            .eq('user_id', userId)
            .maybeSingle();
        isLiked = likedData != null;
      } catch (e) {
        print('Warning: Failed to fetch single post like status: $e');
      }
    }
    
    return PostModel.fromJson(data, isLiked: isLiked);
  }

  Stream<PostModel> watchPost(String postId) async* {
    try {
      final initialData = await getPost(postId);
      yield initialData;
    } catch (e) {
      print('Error fetching initial post $postId: $e');
      rethrow;
    }

    final postStream = _client
        .from(SupabaseConstants.postsTable)
        .stream(primaryKey: ['id'])
        .eq('id', postId)
        .asyncMap((_) => getPost(postId))
        .handleError((err) {
          print('Supabase watchPost stream error: $err');
          _service.handleAuthError(err);
        });

    try {
      await for (final post in postStream) {
        yield post;
      }
    } catch (e) {
      print('Supabase watchPost main stream error: $e');
    }
  }

  // ── Like / Unlike ──
  Future<void> likePost(String postId) async {
    await _client.from(SupabaseConstants.likesTable).insert({
      'post_id': postId,
      'user_id': currentUserId,
    });
  }

  Future<void> unlikePost(String postId) async {
    await _client
        .from(SupabaseConstants.likesTable)
        .delete()
        .eq('post_id', postId)
        .eq('user_id', currentUserId!);
  }

  Future<bool> isLiked(String postId) async {
    final data = await _client
        .from(SupabaseConstants.likesTable)
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', currentUserId!)
        .maybeSingle();
    return data != null;
  }

  // ── Comments ──
  Future<List<CommentModel>> getComments(String postId) async {
    final userId = currentUserId;
    
    final commentsData = await _client
        .from(SupabaseConstants.commentsTable)
        .select('*, profiles(*)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    final commentsList = commentsData as List;
    if (commentsList.isEmpty) return [];

    if (userId == null) {
      return commentsList.map((e) => CommentModel.fromJson(e)).toList();
    }

    // Fetch likes for these comments by current user
    final commentIds = commentsList.map((e) => e['id']).toList();
    Set<String> likedCommentIds = {};
    try {
      final likedCommentsData = await _client
          .from('comment_likes')
          .select('comment_id')
          .eq('user_id', userId)
          .inFilter('comment_id', commentIds);

      likedCommentIds = (likedCommentsData as List).map((e) => e['comment_id'] as String).toSet();
    } catch (e) {
      // Gracefully fall back if the comment_likes table or schema does not exist yet
      print('Warning: Failed to fetch comment likes: $e');
    }

    return commentsList.map((e) {
      return CommentModel.fromJson(e, isLiked: likedCommentIds.contains(e['id']));
    }).toList();
  }

  Stream<List<CommentModel>> watchComments(String postId) async* {
    try {
      final initialData = await getComments(postId);
      yield initialData;
    } catch (e) {
      print('Error fetching initial comments for post $postId: $e');
      rethrow;
    }

    final commentsStream = _client
        .from(SupabaseConstants.commentsTable)
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .order('created_at', ascending: true)
        .asyncMap((_) => getComments(postId))
        .handleError((err) {
          print('Supabase watchComments stream error: $err');
          _service.handleAuthError(err);
        });

    try {
      await for (final comments in commentsStream) {
        yield comments;
      }
    } catch (e) {
      print('Supabase watchComments main stream error: $e');
    }
  }

  Future<CommentModel> addComment(String postId, String content, {String? parentId}) async {
    final data = await _client
        .from(SupabaseConstants.commentsTable)
        .insert({
          'post_id': postId,
          'user_id': currentUserId,
          'content': content,
          if (parentId != null) 'parent_id': parentId,
        })
        .select('*, profiles(*)')
        .single();
    return CommentModel.fromJson(data);
  }

  Future<void> deleteComment(String commentId) async {
    await _client
        .from(SupabaseConstants.commentsTable)
        .delete()
        .eq('id', commentId);
  }

  // ── Comment Likes ──
  Future<void> likeComment(String commentId) async {
    await _client.from('comment_likes').insert({
      'comment_id': commentId,
      'user_id': currentUserId,
    });
  }

  Future<void> unlikeComment(String commentId) async {
    await _client
        .from('comment_likes')
        .delete()
        .eq('comment_id', commentId)
        .eq('user_id', currentUserId!);
  }

  // ── Reports ──
  Future<void> reportPost({required String postId, required String reason}) async {
    final currentId = currentUserId;
    if (currentId == null) throw Exception('Not authenticated');

    // Ánh xạ lý do tiếng Việt sang category name trong database
    String categoryName = 'spam';
    if (reason.contains('Bạo lực')) {
      categoryName = 'violence';
    } else if (reason.contains('Tình dục')) {
      categoryName = 'adult';
    } else if (reason.contains('Lừa đảo')) {
      categoryName = 'scam';
    } else if (reason.contains('Ngôn từ thù ghét')) {
      categoryName = 'hate_speech';
    } else if (reason.contains('Quấy rối')) {
      categoryName = 'harassment';
    }

    await _client.functions.invoke(
      'report-service',
      body: {
        'reporterId': currentId,
        'contentId': postId,
        'contentType': 'post',
        'categoryName': categoryName,
        'description': reason,
      },
    );
  }

  Future<void> cancelReportPost(String postId) async {
    // Không làm gì vì bảng reports cũ đã bị xóa và thay bằng hệ thống động
  }

  // ── Trash & Edit Operations ──
  Future<void> moveToTrash(String postId) async {
    await _client
        .from(SupabaseConstants.postsTable)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', postId)
        .select();
  }

  Future<void> restoreFromTrash(String postId) async {
    await _client
        .from(SupabaseConstants.postsTable)
        .update({'deleted_at': null})
        .eq('id', postId)
        .select();
  }

  Future<void> updatePostCaption(String postId, String newCaption) async {
    await _client
        .from(SupabaseConstants.postsTable)
        .update({'caption': newCaption})
        .eq('id', postId);
  }
  Future<List<PostModel>> getTrashedPosts() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final data = await _client
          .from(SupabaseConstants.postsTable)
          .select('*, profiles(*), post_media(*)')
          .eq('user_id', userId)
          .filter('deleted_at', 'is', 'not_null')
          .order('deleted_at', ascending: false);

      final list = (data as List).map((e) => PostModel.fromJson(e)).toList();
      return list;
    } catch (e) {
      print('Error fetching trashed posts: $e');
      return [];
    }
  }
}
