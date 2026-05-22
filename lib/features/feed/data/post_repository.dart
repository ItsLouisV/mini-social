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

    final data = await _client
        .from(SupabaseConstants.postsTable)
        .select('*, profiles(*), post_media(*)')
        .order('created_at', ascending: false)
        .range(from, to);

    return (data as List).map((e) => PostModel.fromJson(e)).toList();
  }

  Stream<List<PostModel>> watchPosts() {
    // Merge 3 streams: posts, likes, comments — any change triggers a fresh fetch
    final postsStream = _client
        .from(SupabaseConstants.postsTable)
        .stream(primaryKey: ['id']);
    final likesStream = _client
        .from(SupabaseConstants.likesTable)
        .stream(primaryKey: ['id']);
    final commentsStream = _client
        .from(SupabaseConstants.commentsTable)
        .stream(primaryKey: ['id']);

    // Combine all 3 streams: whenever any one emits, fetch the full feed
    return StreamGroup.merge([postsStream, likesStream, commentsStream])
        .asyncMap((_) => getFeedPosts());
  }

  // ── Create Post ──
  Future<PostModel> createPost({
    required String caption,
    required List<XFile> media,
  }) async {
    final userId = currentUserId!;
    final postId = _uuid.v4();

    // 1. Insert post first
    await _client.from(SupabaseConstants.postsTable).insert({
      'id': postId,
      'user_id': userId,
      'caption': caption,
    });

    // 2. Upload media and insert media records
    for (int i = 0; i < media.length; i++) {
      final item = media[i];
      final mediaId = _uuid.v4();
      
      final extension = item.name.split('.').last.toLowerCase();
      final isVideo = ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(extension);
      final fileExtension = isVideo ? extension : 'jpg';
      final path = '$userId/$postId/$i.$fileExtension';
      final mediaType = isVideo ? 'video' : 'image';
      
      final url = await _service.uploadFile(
        bucket: SupabaseConstants.postsBucket,
        path: path,
        file: item,
      );

      await _client.from(SupabaseConstants.postMediaTable).insert({
        'id': mediaId,
        'post_id': postId,
        'url': url,
        'type': mediaType,
        'order_index': i,
      });
    }

    // 3. Fetch the complete post
    return getPost(postId);
  }

  // ── Delete Post ──
  Future<void> deletePost(String postId) async {
    await _client.from(SupabaseConstants.postsTable).delete().eq('id', postId);
  }

  // ── Get Single Post ──
  Future<PostModel> getPost(String postId) async {
    final data = await _client
        .from(SupabaseConstants.postsTable)
        .select('*, profiles(*), post_media(*)')
        .eq('id', postId)
        .single();
    return PostModel.fromJson(data);
  }

  Stream<PostModel> watchPost(String postId) {
    return _client
        .from(SupabaseConstants.postsTable)
        .stream(primaryKey: ['id'])
        .eq('id', postId)
        .asyncMap((_) => getPost(postId));
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

  Stream<List<CommentModel>> watchComments(String postId) {
    return _client
        .from(SupabaseConstants.commentsTable)
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .order('created_at', ascending: true)
        .asyncMap((_) => getComments(postId));
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
}
