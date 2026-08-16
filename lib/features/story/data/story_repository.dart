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

  /// Create & Publish a new Story
  Future<StoryModel?> createStory({
    XFile? imageFile,
    String? caption,
    MusicTrackModel? musicTrack,
    String backgroundColor = '#1C1C1E',
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
}
