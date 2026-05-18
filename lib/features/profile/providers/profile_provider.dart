import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/profile_repository.dart';
import '../domain/profile_model.dart';
import '../../../core/services/supabase_service.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseServiceProvider));
});

final profileProvider =
    FutureProvider.family<ProfileModel, String>((ref, userId) async {
  return ref.watch(profileRepositoryProvider).getProfile(userId);
});

// Provider để invalidate / refresh profile
final profileRefreshProvider = StateProvider<int>((ref) => 0);

final userPostsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, userId) async {
  ref.watch(profileRefreshProvider);
  return ref.watch(profileRepositoryProvider).getUserPosts(userId);
});
