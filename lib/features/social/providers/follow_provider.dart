import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/social_repository.dart';
import '../../../shared/providers/supabase_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository(ref.watch(supabaseClientProvider));
});

final isFollowingProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  final currentUserId = ref.watch(currentUserIdProvider);
  if (currentUserId == null || currentUserId == userId) return false;
  return ref.watch(socialRepositoryProvider).isFollowing(userId);
});

// Follow action notifier
class FollowActionsNotifier extends StateNotifier<Set<String>> {
  final SocialRepository _repo;

  FollowActionsNotifier(this._repo) : super({});

  Future<void> follow(String userId) async {
    try {
      await _repo.follow(userId);
      state = {...state, userId};
    } catch (_) {}
  }

  Future<void> unfollow(String userId) async {
    try {
      await _repo.unfollow(userId);
      state = state.where((id) => id != userId).toSet();
    } catch (_) {}
  }
}

final followActionsProvider =
    StateNotifierProvider<FollowActionsNotifier, Set<String>>((ref) {
  return FollowActionsNotifier(ref.watch(socialRepositoryProvider));
});

// Notifications stream
final notificationsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentUserId = ref.watch(currentUserIdProvider);
  if (currentUserId == null) return const Stream.empty();
  return ref.watch(socialRepositoryProvider).watchNotifications();
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.when(
    data: (list) => list.where((n) => n['is_read'] == false).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
