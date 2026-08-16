import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../domain/music_track_model.dart';

class MusicRepository {
  final http.Client _client;

  MusicRepository({http.Client? client}) : _client = client ?? http.Client();

  /// Search tracks on iTunes Search API
  Future<List<MusicTrackModel>> searchTracks(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return getTrendingTracks();
    }

    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(trimmed)}&media=music&entity=song&limit=25',
      );
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];

        return results
            .map((item) => MusicTrackModel.fromJson(item as Map<String, dynamic>))
            .where((track) => track.previewUrl.isNotEmpty && track.title.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching tracks from iTunes API: $e');
    }
    return [];
  }

  /// Get trending/featured tracks
  Future<List<MusicTrackModel>> getTrendingTracks() async {
    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search?term=vietnam+pop&media=music&entity=song&limit=25',
      );
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];

        return results
            .map((item) => MusicTrackModel.fromJson(item as Map<String, dynamic>))
            .where((track) => track.previewUrl.isNotEmpty && track.title.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching trending tracks: $e');
    }
    return [];
  }
}
