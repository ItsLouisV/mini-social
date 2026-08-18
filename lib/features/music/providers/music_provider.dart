import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/supabase_provider.dart';
import '../data/music_repository.dart';
import '../domain/music_track_model.dart';

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return MusicRepository(supabase: supabase);
});

final musicSearchQueryProvider = StateProvider<String>((ref) => '');

final musicSearchResultsProvider =
    FutureProvider<List<MusicTrackModel>>((ref) async {
  final query = ref.watch(musicSearchQueryProvider);
  final repo = ref.watch(musicRepositoryProvider);
  return repo.searchTracks(query);
});

final activePlayingTrackProvider =
    StateProvider<MusicTrackModel?>((ref) => null);
final isAudioPlayingProvider = StateProvider<bool>((ref) => false);
