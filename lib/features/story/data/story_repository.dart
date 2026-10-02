import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/supabase_service.dart';
import '../../music/domain/music_track_model.dart';
import '../domain/story_model.dart';

class StoryRepository {
  final SupabaseService _service;
  final _uuid = const Uuid();

  StoryRepository(this._service);

  SupabaseClient get _client => _service.client;
  String? get currentUserId => _service.currentUserId;

  /// Fetch active unexpired stories (created in last 24h)
  Future<List<StoryModel>> getActiveStories() async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final data = await _client
          .from('stories')
          .select('*, profiles(*)')
          .gt('expires_at', now)
          .order('created_at', ascending: false);

      final list = (data as List)
          .map((e) => StoryModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return list;
    } catch (e) {
      debugPrint('Warning: Could not fetch active stories: $e');
      return [];
    }
  }

  /// Fetch all stories posted by a user from the past to present (including expired)
  Future<List<StoryModel>> getUserStories(String userId) async {
    try {
      final data = await _client
          .from('stories')
          .select('*, profiles(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final list = (data as List)
          .map((e) => StoryModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return list;
    } catch (e) {
      debugPrint('Warning: Could not fetch user stories: $e');
      return [];
    }
  }

  /// Create & Publish a new Story
  Future<StoryModel?> createStory({
    XFile? imageFile,
    String? caption,
    MusicTrackModel? musicTrack,
    String backgroundColor = '#1C1C1E',
    Map<String, dynamic>? metadata,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final storyId = _uuid.v4();
    String? mediaUrl;

    if (imageFile != null) {
      final ext = imageFile.name.split('.').last.toLowerCase();
      final path = '$userId/stories/$storyId.$ext';
      mediaUrl = await _service.uploadFile(
        bucket: 'posts',
        path: path,
        file: imageFile,
      );
    }

    final insertData = <String, dynamic>{
      'id': storyId,
      'user_id': userId,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (caption != null && caption.trim().isNotEmpty) 'caption': caption.trim(),
      if (musicTrack != null) 'music_track': musicTrack.toJson(),
      'background_color': backgroundColor,
      if (metadata != null) 'metadata': metadata,
    };

    final result = await _client
        .from('stories')
        .insert(insertData)
        .select('*, profiles(*)')
        .single();

    return StoryModel.fromJson(Map<String, dynamic>.from(result));
  }

  /// Delete a story
  Future<void> deleteStory(String storyId) async {
    await _client.from('stories').delete().eq('id', storyId);
  }

  final Set<String> _syncedReactions = {};

  /// Send a reaction to a story (stores only one record per emoji type per user)
  Future<void> sendStoryReaction({
    required String storyId,
    required String reaction,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    final key = '$userId:$storyId:$reaction';
    if (_syncedReactions.contains(key)) {
      // Already saved this specific emoji for this story in current session
      return;
    }

    _syncedReactions.add(key);

    try {
      await _client.from('story_reactions').upsert(
        {
          'story_id': storyId,
          'user_id': userId,
          'reaction': reaction,
        },
        onConflict: 'story_id,user_id,reaction',
        ignoreDuplicates: true,
      );
    } catch (e) {
      debugPrint('Warning: Could not save story reaction: $e');
    }
  }

  /// Get reactions for a specific story
  Future<List<Map<String, dynamic>>> getStoryReactions(String storyId) async {
    try {
      final res = await _client
          .from('story_reactions')
          .select('id, reaction, created_at, profiles(*)')
          .eq('story_id', storyId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('Warning: Could not fetch story reactions: $e');
      return [];
    }
  }
}
