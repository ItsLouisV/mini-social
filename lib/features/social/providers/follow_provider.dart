import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/social_repository.dart';
import '../../../shared/providers/supabase_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';

import '../../profile/providers/profile_provider.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository(ref.watch(supabaseClientProvider));
});

final isFollowingProvider = StateNotifierProvider.family<IsFollowingNotifier, AsyncValue<bool>, String>((ref, userId) {
  return IsFollowingNotifier(ref, userId);
});

class IsFollowingNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref ref;
  final String userId;

  IsFollowingNotifier(this.ref, this.userId) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final currentUserId = ref.read(currentUserIdProvider);
      if (currentUserId == null || currentUserId == userId) {
        if (mounted) state = const AsyncValue.data(false);
        return;
      }
      final isFollowing = await ref.read(socialRepositoryProvider).isFollowing(userId);
      if (mounted) state = AsyncValue.data(isFollowing);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleFollow() async {
    final previousState = state.valueOrNull ?? false;
    
    // Optimistic Update: Update UI immediately
    state = AsyncValue.data(!previousState);

    try {
      if (previousState) {
        await ref.read(socialRepositoryProvider).unfollow(userId);
      } else {
        await ref.read(socialRepositoryProvider).follow(userId);
      }
      // Invalidate profile to update follower counts in real-time
      ref.invalidate(profileProvider(userId));
    } catch (e) {
      // Revert if API call fails
      if (mounted) state = AsyncValue.data(previousState);
    }
  }
}

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
