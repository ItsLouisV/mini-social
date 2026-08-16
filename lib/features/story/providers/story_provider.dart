import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../data/story_repository.dart';
import '../domain/story_model.dart';

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  return StoryRepository(ref.watch(supabaseServiceProvider));
});

final activeStoriesProvider = FutureProvider<List<StoryModel>>((ref) async {
  final repo = ref.watch(storyRepositoryProvider);
  return repo.getActiveStories();
});
