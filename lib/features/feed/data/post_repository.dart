import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/comment_model.dart';
import '../domain/post_model.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../location/domain/place_model.dart';

import '../../../core/services/isar_service.dart';
import '../../../core/services/sync_engine.dart';

class PostRepository {
  final SupabaseService _service;
  final IsarService? _isarService;
  final SyncEngine? _syncEngine;
  final _uuid = const Uuid();

  PostRepository(
    this._service, [
    this._isarService,
    this._syncEngine,
  ]);

  SupabaseClient get _client => _service.client;
  String? get currentUserId => _service.currentUserId;

  // ── Feed ──
  Future<List<PostModel>> getFeedPosts(
      {int page = 0, int pageSize = 20}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    try {
      final data = await _client
          .from(SupabaseConstants.postsTable)
          .select('*, profiles(*), post_media(*)')
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: false);

      final postsList = data as List;
      if (postsList.isEmpty) return [];

      final userId = currentUserId;
      if (userId == null) {
        final publicOnly = postsList.where((p) {
          final status = p['moderation_status'] as String? ?? 'pending';
          final privacy = p['privacy'] as String? ?? 'public';
          return (status == 'published' || status == 'shadow_limited') &&
              privacy == 'public';
        });
        return publicOnly.map((e) => PostModel.fromJson(e)).toList();
      }

      // 1. Get the current user's follows
      Set<String> followingIds = {};
      try {
        final followingData = await _client
            .from(SupabaseConstants.followsTable)
            .select('following_id')
            .eq('follower_id', userId);
        followingIds = (followingData as List)
            .map((x) => x['following_id'] as String)
            .toSet();
      } catch (e) {
        print('Warning: Failed to fetch following: $e');
      }

      // 2. Get the current user's friends
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

      // 3. Filter posts
      final filteredPostsList = postsList.where((postJson) {
        final postUserId = postJson['user_id'] as String;
        final status = postJson['moderation_status'] as String? ?? 'pending';

        if (status == 'hidden' ||
            status == 'removed' ||
            status == 'under_review') return false;
        if (postUserId == userId) return true;
        if (status != 'published' && status != 'shadow_limited') return false;

        final privacy = postJson['privacy'] as String? ?? 'public';
        if (privacy == 'public') return true;
        if (privacy == 'private') return false;
        if (privacy == 'friends' || privacy == 'followers') {
          return friendIds.contains(postUserId) ||
              followingIds.contains(postUserId);
        }
        return true;
      }).toList()
        ..sort((a, b) {
          final aRestricted = a['moderation_status'] == 'shadow_limited';
          final bRestricted = b['moderation_status'] == 'shadow_limited';
          if (aRestricted != bRestricted) return aRestricted ? 1 : -1;
          return DateTime.parse(b['created_at'] as String)
              .compareTo(DateTime.parse(a['created_at'] as String));
        });

      if (from >= filteredPostsList.length) return [];
      final paginatedList = filteredPostsList.sublist(
        from,
        (to + 1) > filteredPostsList.length
            ? filteredPostsList.length
            : (to + 1),
      );

      final postIds = paginatedList.map((e) => e['id']).toList();
      Set<String> likedPostIds = {};
      try {
        final likedPostsData = await _client
            .from(SupabaseConstants.likesTable)
            .select('post_id')
            .eq('user_id', userId)
            .inFilter('post_id', postIds);

        likedPostIds =
            (likedPostsData as List).map((e) => e['post_id'] as String).toSet();
      } catch (e) {
        print('Warning: Failed to fetch post likes: $e');
      }

      final resultPosts = paginatedList.map((e) {
        return PostModel.fromJson(e, isLiked: likedPostIds.contains(e['id']));
      }).toList();

      // Sync posts to local DB (platform-independent)
      if (_isarService != null && resultPosts.isNotEmpty) {
        final jsonList = resultPosts.map((p) => p.toJson()).toList();
        await _isarService!.savePosts(jsonList);
      }

      return resultPosts;
    } catch (e) {
      debugPrint(
          '⚠️ [PostRepository] Offline fallback for feed: loading from local DB: $e');
      // Offline fallback
      if (_isarService != null) {
        final cached = _isarService!.getPosts(limit: pageSize, offset: from);
        return cached.map((p) => PostModel.fromJson(p)).toList();
      }
      rethrow;
    }
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

    final changes = StreamController<void>();
    Timer? debounce;
    void notifyChange(PostgresChangePayload _) {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 350), () {
        if (!changes.isClosed) changes.add(null);
      });
    }

    // One channel can carry multiple Postgres subscriptions. This replaces
    // the three `.stream()` channels previously used for posts, likes and
    // comments and also coalesces burst events into a single feed refresh.
    final channel = _client
        .channel('feed:posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConstants.postsTable,
          callback: notifyChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConstants.likesTable,
          callback: notifyChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConstants.commentsTable,
          callback: notifyChange,
        );

    channel.subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.channelError) {
        if (error != null) debugPrint('Supabase feed Realtime error: $error');
        unawaited(_service.handleRealtimeError(error));
      }
    });

    try {
      await for (final _ in changes.stream) {
        try {
          yield await getFeedPosts();
        } catch (error) {
          debugPrint('Unable to refresh feed after Realtime event: $error');
        }
      }
    } finally {
      debounce?.cancel();
      await changes.close();
      await _client.removeChannel(channel);
    }
  }

  // ── Create Post ──
  Future<PostModel> createPost({
    required String caption,
    required List<XFile> media,
    String privacy = 'public',
    String layoutType = 'grid',
    String? postId,
    int? moderationScore,
    String? moderationStatus,
    bool isAiGenerated = false,
    PlaceModel? location,
  }) async {
    final userId = currentUserId!;
    final finalPostId = postId ?? _uuid.v4();

    final finalCaption = media.length >= 3
        ? (caption.trim().isNotEmpty
            ? '${caption.trim()}\n[layout:$layoutType]'
            : '[layout:$layoutType]')
        : caption;

    // 1. Insert post first
    final insertData = <String, dynamic>{
      'id': finalPostId,
      'user_id': userId,
      'caption': finalCaption,
      'privacy': privacy,
      if (isAiGenerated) 'is_ai_generated': true,
      if (moderationScore != null) 'ai_moderation_score': moderationScore,
      if (moderationStatus != null) 'moderation_status': moderationStatus,
      if (location != null) ...{
        'location_place_id': location.providerPlaceId,
        'location_name': location.name,
        'location_address': location.address,
        'location_latitude': location.latitude,
        'location_longitude': location.longitude,
        'location_provider': location.provider,
      },
    };

    try {
      insertData['layout_type'] = layoutType;
      await _client.from(SupabaseConstants.postsTable).insert(insertData);
    } catch (_) {
      try {
        insertData.remove('layout_type');
        await _client.from(SupabaseConstants.postsTable).insert(insertData);
      } catch (_) {
        insertData.remove('is_ai_generated');
        await _client.from(SupabaseConstants.postsTable).insert(insertData);
      }
    }

    final uploadedMediaUrls = <String>[];

    // 2. Upload media and insert media records
    for (int i = 0; i < media.length; i++) {
      final item = media[i];
      final mediaId = _uuid.v4();

      final extension = item.name.split('.').last.toLowerCase();
      final isVideo =
          ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(extension);
      final fileExtension = isVideo ? extension : 'jpg';
      final path = '$userId/$finalPostId/$i.$fileExtension';
      final mediaType = isVideo ? 'video' : 'image';

      final url = await _service.uploadFile(
        bucket: SupabaseConstants.postsBucket,
        path: path,
        file: item,
      );

      if (!isVideo) {
        uploadedMediaUrls.add(url);
      }

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
        await _client
            .from(SupabaseConstants.postMediaTable)
            .insert(mediaInsertData);
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

    // 3. Trigger async moderate-content Edge Function in background (non-blocking)
    _safeInvokeFunction(
      'moderate-content',
      body: {
        'content_type': 'post',
        'target_id': finalPostId,
        'content': finalCaption,
        'image_urls': uploadedMediaUrls,
      },
    );

    // 4. Fetch the complete post
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
      debugPrint(
          'Warning: Could not delete storage files for post $postId: $e');
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
    final moderationStatus = data['moderation_status'] as String? ?? 'pending';
    final isOwner = userId != null && postUserId == userId;

    // Chặn người khác xem bài chưa được AI xác nhận an toàn (kể cả qua link trực tiếp)
    if (!isOwner &&
        moderationStatus != 'published' &&
        moderationStatus != 'shadow_limited') {
      throw Exception('Bài viết này hiện không khả dụng.');
    }

    if (!isOwner) {
      if (privacy == 'private') {
        throw Exception('Bài viết này là riêng tư.');
      }
      if (privacy == 'friends' || privacy == 'followers') {
        final isFriend = await _isFriend(userId!, postUserId);
        final isFollowing = await _isFollowing(userId, postUserId);
        if (!isFriend && !isFollowing) {
          throw Exception(
              'Bài viết này chỉ dành cho bạn bè và người theo dõi.');
        }
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

    final commentsList = (commentsData as List).where((comment) {
      final status = comment['moderation_status'] as String? ?? 'published';
      return status == 'published' || status == 'shadow_limited';
    }).toList();
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

      likedCommentIds = (likedCommentsData as List)
          .map((e) => e['comment_id'] as String)
          .toSet();
    } catch (e) {
      // Gracefully fall back if the comment_likes table or schema does not exist yet
      print('Warning: Failed to fetch comment likes: $e');
    }

    return commentsList.map((e) {
      return CommentModel.fromJson(e,
          isLiked: likedCommentIds.contains(e['id']));
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

    final changes = StreamController<void>();
    Timer? debounce;
    final channel = _client.channel('post-comments:$postId');

    channel
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: SupabaseConstants.commentsTable,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'post_id',
        value: postId,
      ),
      callback: (_) {
        debounce?.cancel();
        debounce = Timer(const Duration(milliseconds: 250), () {
          if (!changes.isClosed) changes.add(null);
        });
      },
    )
        .subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.channelError) {
        if (error != null) {
          debugPrint('Supabase comments Realtime error: $error');
        }
        unawaited(_service.handleRealtimeError(error));
      }
    });

    try {
      await for (final _ in changes.stream) {
        try {
          yield await getComments(postId);
        } catch (error) {
          debugPrint('Unable to refresh comments after Realtime event: $error');
        }
      }
    } finally {
      debounce?.cancel();
      await changes.close();
      await _client.removeChannel(channel);
    }
  }

  Future<CommentModel> addComment(String postId, String content,
      {String? parentId}) async {
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

    final comment = CommentModel.fromJson(data);

    // Trigger async moderate-content Edge Function in background (non-blocking)
    _safeInvokeFunction(
      'moderate-content',
      body: {
        'content_type': 'comment',
        'target_id': comment.id,
        'content': content,
      },
    );

    return comment;
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
  Future<void> reportPost(
      {required String postId, required String reason}) async {
    final currentId = currentUserId;
    if (currentId == null) throw Exception('Not authenticated');

    String validReason = 'other';
    final r = reason.toLowerCase();
    if (r.contains('spam') || r.contains('rác')) {
      validReason = 'spam';
    } else if (r.contains('quấy rối') || r.contains('harass')) {
      validReason = 'harassment';
    } else if (r.contains('tình dục') || r.contains('nude')) {
      validReason = 'nudity_sexual';
    } else if (r.contains('bạo lực') || r.contains('violence')) {
      validReason = 'violence_gore';
    } else if (r.contains('thù ghét') || r.contains('hate')) {
      validReason = 'hate_speech';
    } else if (r.contains('lừa đảo') || r.contains('sai sự thật')) {
      validReason = 'misinformation';
    }

    final data = await _client
        .from('reports')
        .insert({
          'content_type': 'post',
          'post_id': postId,
          'reporter_id': currentId,
          'reason': validReason,
          'description': reason,
          'status': 'pending',
        })
        .select('id')
        .single();

    final reportId = data['id'] as String;

    // Trigger process-report Edge Function in background
    _safeInvokeFunction(
      'process-report',
      body: {
        'report_id': reportId,
      },
    );
  }

  Future<void> cancelReportPost(String postId) async {}

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

  Future<void> updatePost({
    required String postId,
    required String caption,
    String privacy = 'public',
    String layoutType = 'panel-top',
    List<PostMedia>? remainingExistingMedia,
    List<XFile>? newMedia,
    int? moderationScore,
    String? moderationStatus,
    bool? isAiGenerated,
    PlaceModel? location,
    bool clearLocation = false,
  }) async {
    final userId = currentUserId!;
    final updateData = <String, dynamic>{
      'caption': caption,
      'privacy': privacy,
      if (isAiGenerated != null) 'is_ai_generated': isAiGenerated,
      if (moderationScore != null) 'ai_moderation_score': moderationScore,
      if (moderationStatus != null) 'moderation_status': moderationStatus,
      if (clearLocation || location != null) ...{
        'location_place_id': clearLocation ? null : location!.providerPlaceId,
        'location_name': clearLocation ? null : location!.name,
        'location_address': clearLocation ? null : location!.address,
        'location_latitude': clearLocation ? null : location!.latitude,
        'location_longitude': clearLocation ? null : location!.longitude,
        'location_provider': clearLocation ? null : location!.provider,
      },
    };
    try {
      updateData['layout_type'] = layoutType;
      await _client
          .from(SupabaseConstants.postsTable)
          .update(updateData)
          .eq('id', postId);
    } catch (_) {
      updateData.remove('layout_type');
      await _client
          .from(SupabaseConstants.postsTable)
          .update(updateData)
          .eq('id', postId);
    }

    // 1. Quản lý media cũ: xóa bản ghi media bị gỡ
    if (remainingExistingMedia != null) {
      try {
        final currentDbMedia = await _client
            .from(SupabaseConstants.postMediaTable)
            .select('id')
            .eq('post_id', postId);

        final remainingIds = remainingExistingMedia.map((m) => m.id).toSet();
        for (final m in (currentDbMedia as List)) {
          final id = m['id'] as String;
          if (!remainingIds.contains(id)) {
            await _client
                .from(SupabaseConstants.postMediaTable)
                .delete()
                .eq('id', id);
          }
        }
      } catch (e) {
        print('Error syncing remaining post media: $e');
      }
    }

    // 2. Upload media mới nếu có
    final uploadedUrls = <String>[];
    if (newMedia != null && newMedia.isNotEmpty) {
      final baseOrderIndex = remainingExistingMedia?.length ?? 0;
      for (int i = 0; i < newMedia.length; i++) {
        final item = newMedia[i];
        final mediaId = _uuid.v4();
        final extension = item.name.split('.').last.toLowerCase();
        final isVideo =
            ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(extension);
        final fileExtension = isVideo ? extension : 'jpg';
        final path = '$userId/$postId/${baseOrderIndex + i}.$fileExtension';
        final mediaType = isVideo ? 'video' : 'image';

        final url = await _service.uploadFile(
          bucket: SupabaseConstants.postsBucket,
          path: path,
          file: item,
        );

        if (!isVideo) uploadedUrls.add(url);

        try {
          await _client.from(SupabaseConstants.postMediaTable).insert({
            'id': mediaId,
            'post_id': postId,
            'url': url,
            'path': path,
            'type': mediaType,
            'order_index': baseOrderIndex + i,
          });
        } catch (_) {
          await _client.from(SupabaseConstants.postMediaTable).insert({
            'id': mediaId,
            'post_id': postId,
            'url': url,
            'type': mediaType,
            'order_index': baseOrderIndex + i,
          });
        }
      }
    }

    // 3. Trigger async moderate-content Edge Function in background (non-blocking)
    _safeInvokeFunction(
      'moderate-content',
      body: {
        'content_type': 'post',
        'target_id': postId,
        'content': caption,
        if (uploadedUrls.isNotEmpty) 'image_urls': uploadedUrls,
      },
    );
  }

  Future<void> updatePostCaption(String postId, String newCaption) async {
    await updatePost(postId: postId, caption: newCaption);
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

  void _safeInvokeFunction(String functionName, {Map<String, dynamic>? body}) {
    Future(() async {
      try {
        await _client.functions.invoke(functionName, body: body);
      } catch (err) {
        print('$functionName background error: $err');
      }
    });
  }
}
