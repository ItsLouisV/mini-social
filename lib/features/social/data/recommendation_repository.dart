import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../feed/domain/post_model.dart';
import '../../profile/domain/profile_model.dart';

class PymkCandidate {
  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String? bio;
  final List<String> interests;
  final int mutualFriendsCount;
  final int sharedInterestsCount;

  const PymkCandidate({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.bio,
    this.interests = const [],
    this.mutualFriendsCount = 0,
    this.sharedInterestsCount = 0,
  });

  factory PymkCandidate.fromJson(Map<String, dynamic> json) {
    return PymkCandidate(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      fullName: json['full_name'] as String? ?? json['username'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      interests: (json['interests'] as List?)?.map((e) => e.toString()).toList() ?? [],
      mutualFriendsCount: json['mutual_friends_count'] as int? ?? 0,
      sharedInterestsCount: json['shared_interests_count'] as int? ?? 0,
    );
  }
}

class RecommendationRepository {
  final SupabaseService _service;

  RecommendationRepository(this._service);

  SupabaseClient get _client => _service.client;

  /// Lấy danh sách bài viết đề xuất xếp hạng cá nhân hóa
  Future<List<PostModel>> getRecommendedFeed({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'recommendation-engine',
        queryParameters: {
          'action': 'feed',
          'userId': userId,
          'limit': '$limit',
          'offset': '$offset',
        },
      );

      if (res.data != null && res.data['posts'] != null) {
        final List list = res.data['posts'] as List;
        return list.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          
          final authorMap = map['user'] != null
              ? Map<String, dynamic>.from(map['user'] as Map)
              : null;
          
          final mediaList = (map['media'] as List?)
                  ?.map((m) => PostMedia.fromJson(Map<String, dynamic>.from(m as Map)))
                  .toList() ??
              [];

          final createdAtRaw = map['createdAt'] ?? map['created_at'];
          final createdAt = createdAtRaw != null
              ? DateTime.parse(createdAtRaw.toString())
              : DateTime.now();

          return PostModel(
            id: (map['id'] ?? '') as String,
            userId: (map['userId'] ?? map['user_id'] ?? '') as String,
            caption: map['caption'] as String?,
            media: mediaList,
            likesCount: (map['likesCount'] ?? map['likes_count'] ?? 0) as int,
            commentsCount: (map['commentsCount'] ?? map['comments_count'] ?? 0) as int,
            createdAt: createdAt,
            author: authorMap != null ? ProfileModel.fromJson(authorMap) : null,
            isLiked: (map['isLiked'] ?? map['is_liked'] ?? false) as bool,
            privacy: (map['privacy'] ?? 'public') as String,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Edge function recommendation error, using RPC fallback: $e');
    }

    // Direct RPC Fallback
    try {
      final List rpcRes = await _client.rpc('get_recommended_feed', params: {
        'p_user_id': userId,
        'p_limit': limit,
        'p_offset': offset,
      });

      if (rpcRes.isEmpty) return [];

      final postIds = rpcRes.map((r) => r['post_id'] as String).toList();
      final authorIds = rpcRes.map((r) => r['user_id'] as String).toSet().toList();

      final authorsRes = await _client.from('profiles').select().inFilter('id', authorIds);
      final authorMap = {for (var a in authorsRes) a['id'] as String: ProfileModel.fromJson(a)};

      final mediaRes = await _client.from('post_media').select().inFilter('post_id', postIds).order('order_index');
      final mediaMap = <String, List<PostMedia>>{};
      for (var m in mediaRes) {
        final pid = m['post_id'] as String;
        mediaMap.putIfAbsent(pid, () => []).add(PostMedia.fromJson(m));
      }

      final likesRes = await _client.from('likes').select('post_id').eq('user_id', userId).inFilter('post_id', postIds);
      final likedSet = {for (var l in likesRes) l['post_id'] as String};

      return rpcRes.map((r) {
        final pid = r['post_id'] as String;
        final uid = r['user_id'] as String;
        return PostModel(
          id: pid,
          userId: uid,
          caption: r['caption'] as String?,
          media: mediaMap[pid] ?? [],
          likesCount: r['likes_count'] as int? ?? 0,
          commentsCount: r['comments_count'] as int? ?? 0,
          createdAt: DateTime.parse(r['created_at'] as String),
          author: authorMap[uid],
          isLiked: likedSet.contains(pid),
          privacy: r['privacy'] as String? ?? 'public',
        );
      }).toList();
    } catch (e) {
      debugPrint('RPC recommendation error: $e');
      return [];
    }
  }

  /// Lấy danh sách gợi ý người quen (People You May Know)
  Future<List<PymkCandidate>> getPeopleYouMayKnow({
    required String userId,
    int limit = 10,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'recommendation-engine',
        queryParameters: {
          'action': 'pymk',
          'userId': userId,
          'limit': '$limit',
        },
      );

      if (res.data != null && res.data['candidates'] != null) {
        final List list = res.data['candidates'] as List;
        final candidates = list.map((item) => PymkCandidate.fromJson(Map<String, dynamic>.from(item as Map))).toList();
        if (candidates.isNotEmpty) return candidates;
      }
    } catch (e) {
      debugPrint('Edge function PYMK error, using RPC fallback: $e');
    }

    try {
      final List rpcRes = await _client.rpc('get_people_you_may_know', params: {
        'p_user_id': userId,
        'p_limit': limit,
      });

      final candidates = rpcRes.map((item) => PymkCandidate.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      if (candidates.isNotEmpty) return candidates;
    } catch (e) {
      debugPrint('RPC PYMK error: $e');
    }

    // Direct profiles fallback so PYMK carousel is always populated
    try {
      final profilesRes = await _client
          .from('profiles')
          .select()
          .neq('id', userId)
          .limit(limit);

      return (profilesRes as List).map((p) => PymkCandidate(
        id: p['id'] as String,
        username: p['username'] as String? ?? '',
        fullName: p['full_name'] as String? ?? p['username'] as String? ?? '',
        avatarUrl: p['avatar_url'] as String?,
        bio: p['bio'] as String?,
        interests: (p['interests'] as List?)?.map((e) => e.toString()).toList() ?? [],
        mutualFriendsCount: 0,
        sharedInterestsCount: 0,
      )).toList();
    } catch (e) {
      debugPrint('Direct profiles fallback error: $e');
      return [];
    }
  }

  /// Gửi tracking tương tác ẩn (Dwell time / Image clicks)
  Future<void> trackInteraction({
    required String userId,
    required String postId,
    required String interactionType,
    int durationMs = 0,
  }) async {
    try {
      await _client.functions.invoke(
        'recommendation-engine',
        queryParameters: {'action': 'track'},
        body: {
          'userId': userId,
          'postId': postId,
          'interactionType': interactionType,
          'durationMs': durationMs,
        },
      );
    } catch (e) {
      // Fallback direct DB insert
      try {
        await _client.from('user_interactions').insert({
          'user_id': userId,
          'post_id': postId,
          'interaction_type': interactionType,
          'duration_ms': durationMs,
        });
      } catch (_) {}
    }
  }
}

final recommendationRepositoryProvider = Provider<RecommendationRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return RecommendationRepository(supabaseService);
});
