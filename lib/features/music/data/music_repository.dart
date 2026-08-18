import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/music_track_model.dart';
import 'itunes_jsonp_helper.dart';

class MusicRepository {
  final SupabaseClient? _supabase;
  final http.Client _client;

  MusicRepository({SupabaseClient? supabase, http.Client? client})
      : _supabase = supabase ??
            (Supabase.instance.isInitialized
                ? Supabase.instance.client
                : null),
        _client = client ?? http.Client();

  /// Search tracks:
  /// Passes query to Supabase Edge Function (itunes-service).
  /// If query is empty, Edge Function automatically merges V-Pop + US-UK Top Hits server-side (100 tracks)!
  Future<List<MusicTrackModel>> searchTracks(String query) async {
    final trimmed = query.trim();

    // 1. Edge Function handles both empty (initial load) and targeted search
    if (_supabase != null) {
      try {
        final response = await _supabase.functions.invoke(
          'itunes-service',
          body: {'term': trimmed, 'limit': 100},
        ).timeout(const Duration(seconds: 8));

        if (response.status == 200 && response.data != null) {
          final data = response.data is Map
              ? Map<String, dynamic>.from(response.data as Map)
              : jsonDecode(response.data.toString()) as Map<String, dynamic>;
          final results = data['results'] as List<dynamic>? ?? [];
          final tracks = results
              .map((item) => MusicTrackModel.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .where((track) =>
                  track.previewUrl.isNotEmpty && track.title.isNotEmpty)
              .toList();
          if (tracks.isNotEmpty) {
            return tracks;
          }
        }
      } catch (e) {
        debugPrint('Supabase Edge Function (itunes-service) invocation notice: $e');
      }
    }

    // 2. Fallback when Edge Function is offline: Local parallel fetch
    if (trimmed.isEmpty) {
      final futures = await Future.wait([
        _fetchSingleSearch('nhac viet', limit: 25),
        _fetchSingleSearch('us uk hit', limit: 25),
        _fetchSingleSearch('v-pop', limit: 25),
        _fetchSingleSearch('top hits', limit: 25),
      ]);

      final Set<String> seenIds = {};
      final List<MusicTrackModel> combined = [];

      for (final list in futures) {
        for (final track in list) {
          if (!seenIds.contains(track.id)) {
            seenIds.add(track.id);
            combined.add(track);
          }
        }
      }
      return combined;
    }

    return _fetchSingleSearch(trimmed, limit: 50);
  }

  /// Single search execution flow: Safari JSONP -> Direct HTTP
  Future<List<MusicTrackModel>> _fetchSingleSearch(String searchTerm,
      {int limit = 50}) async {
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
        debugPrint('JSONP search fallback error: $e');
      }
    }

    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(searchTerm)}&media=music&entity=song&limit=$limit',
      );
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 8));

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
      debugPrint('Direct HTTP search fallback error: $e');
    }

    return [];
  }

  /// Get trending/featured tracks
  Future<List<MusicTrackModel>> getTrendingTracks() async {
    return searchTracks('');
  }
}
