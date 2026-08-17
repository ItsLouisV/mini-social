import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../domain/music_track_model.dart';
import 'itunes_jsonp_helper.dart';

class MusicRepository {
  final http.Client _client;

  MusicRepository({http.Client? client}) : _client = client ?? http.Client();

  /// Search tracks on iTunes Search API (with Safari JSONP support)
  Future<List<MusicTrackModel>> searchTracks(String query) async {
    final trimmed = query.trim();
    final searchTerm = trimmed.isEmpty ? 'vietnam pop' : trimmed;

    // 1. On Web (Safari / Chrome), use JSONP script injection to bypass CORS restrictions
    if (kIsWeb) {
      try {
        final jsonpResults = await getItunesJsonp(searchTerm);
        if (jsonpResults.isNotEmpty) {
          return jsonpResults
              .map((item) => MusicTrackModel.fromJson(item))
              .where((track) =>
                  track.previewUrl.isNotEmpty && track.title.isNotEmpty)
              .toList();
        }
      } catch (e) {
        debugPrint('JSONP search attempt error: $e');
      }
    }

    // 2. Direct HTTP call for Native (Android/iOS) or HTTP fallback
    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(searchTerm)}&media=music&entity=song&limit=25',
      );
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];

        return results
            .map((item) =>
                MusicTrackModel.fromJson(item as Map<String, dynamic>))
            .where((track) =>
                track.previewUrl.isNotEmpty && track.title.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('Direct HTTP search attempt error: $e');
    }

    return [];
  }

  /// Get trending/featured tracks
  Future<List<MusicTrackModel>> getTrendingTracks() async {
    return searchTracks('vietnam pop');
  }
}
