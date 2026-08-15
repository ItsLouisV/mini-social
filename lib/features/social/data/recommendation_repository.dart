import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/supabase_service.dart';
import '../../feed/domain/post_model.dart';

class PymkCandidate {
  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String? bio;
  final List<String> interests;
  final int mutualFriendsCount;
  final int sharedInterestsCount;
  final double score;
  final List<String> reasonCodes;

  const PymkCandidate({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.bio,
    this.interests = const [],
    this.mutualFriendsCount = 0,
    this.sharedInterestsCount = 0,
    this.score = 0,
    this.reasonCodes = const [],
  });

  factory PymkCandidate.fromJson(Map<String, dynamic> json) => PymkCandidate(
        id: json['id'] as String,
        username: json['username'] as String? ?? '',
        fullName:
            json['full_name'] as String? ?? json['username'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String?,
        interests:
            (json['interests'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        mutualFriendsCount:
            (json['mutual_friends_count'] as num?)?.toInt() ?? 0,
        sharedInterestsCount:
            (json['shared_interests_count'] as num?)?.toInt() ?? 0,
        score: (json['score'] as num?)?.toDouble() ?? 0,
        reasonCodes: (json['reason_codes'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}

class RecommendationRepository {
  RecommendationRepository(this._service);

  final SupabaseService _service;
  static const _uuid = Uuid();
  SupabaseClient get _client => _service.client;

  Future<FunctionResponse> _invoke({
    required Map<String, String> queryParameters,
    Map<String, dynamic>? body,
  }) async {
    Future<FunctionResponse> request() => _client.functions.invoke(
          'recommendation-engine',
          queryParameters: queryParameters,
          body: body,
        );

    try {
      return await request();
    } catch (error) {
      final refreshed = await _service.handleAuthError(error);
      if (!refreshed) rethrow;
      return request();
    }
  }

  Future<List<PostModel>> getRecommendedFeed({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    if (_service.currentUserId != userId || userId.isEmpty) return [];
    try {
      final response = await _invoke(
        queryParameters: {'action': 'feed', 'limit': '${limit.clamp(1, 50)}'},
      );
      final raw = response.data is Map ? response.data['posts'] : null;
      if (raw is! List) return [];
      return raw
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((item) {
            final status = item['moderation_status'] ?? 'published';
            return status == 'published' || status == 'shadow_limited';
          })
          .map((item) =>
              PostModel.fromJson(item, isLiked: item['is_liked'] == true))
          .toList(growable: false);
    } catch (error) {
      debugPrint('Recommendation feed unavailable: $error');
      return [];
    }
  }

  Future<List<PymkCandidate>> getPeopleYouMayKnow({
    required String userId,
    int limit = 10,
  }) async {
    if (_service.currentUserId != userId || userId.isEmpty) return [];
    try {
      final response = await _invoke(
        queryParameters: {'action': 'pymk', 'limit': '${limit.clamp(1, 30)}'},
      );
      final raw = response.data is Map ? response.data['candidates'] : null;
      if (raw is! List) return [];
      return raw
          .map((item) =>
              PymkCandidate.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false);
    } catch (error) {
      debugPrint('People recommendations unavailable: $error');
      return [];
    }
  }

  Future<void> trackInteraction({
    required String userId,
    required String postId,
    required String interactionType,
    int durationMs = 0,
    double? visibleRatio,
    int? position,
    String? source,
  }) async {
    if (_service.currentUserId != userId || userId.isEmpty) return;
    try {
      await _invoke(
        queryParameters: {'action': 'track'},
        body: {
          'eventId': _uuid.v4(),
          'postId': postId,
          'interactionType': interactionType,
          'durationMs': durationMs.clamp(0, 600000),
          if (visibleRatio != null) 'visibleRatio': visibleRatio.clamp(0, 1),
          if (position != null) 'position': position,
          if (source != null) 'source': source,
        },
      );
    } catch (error) {
      debugPrint('Recommendation tracking unavailable: $error');
    }
  }

  Future<void> dismissProfile(String profileId) async {
    try {
      await _invoke(
        queryParameters: {'action': 'dismiss-profile'},
        body: {'profileId': profileId},
      );
    } catch (error) {
      debugPrint('Dismiss profile recommendation unavailable: $error');
    }
  }
}

final recommendationRepositoryProvider =
    Provider<RecommendationRepository>((ref) {
  return RecommendationRepository(ref.watch(supabaseServiceProvider));
});
