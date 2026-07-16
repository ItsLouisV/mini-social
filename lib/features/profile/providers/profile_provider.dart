import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/profile_repository.dart';
import '../domain/profile_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../feed/domain/post_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseServiceProvider));
});

final profileProvider =
    FutureProvider.family<ProfileModel, String>((ref, userId) async {
  final supabase = ref.watch(supabaseServiceProvider).client;
  
  final channel = supabase.channel('public:profile_$userId');
  
  try {
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'follows',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'following_id',
        value: userId,
      ),
      callback: (payload) {
        ref.invalidateSelf();
      },
    ).onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'follows',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'follower_id',
        value: userId,
      ),
      callback: (payload) {
        ref.invalidateSelf();
      },
    ).onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'profiles',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: userId,
      ),
      callback: (payload) {
        ref.invalidateSelf();
      },
    ).subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.channelError) {
        print('Supabase Realtime profile channel error: $error');
      }
    });
  } catch (e) {
    print('Error subscribing to realtime profile: $e');
  }

  ref.onDispose(() {
    try {
      channel.unsubscribe();
    } catch (_) {}
  });

  return ref.watch(profileRepositoryProvider).getProfile(userId);
});

// Provider để invalidate / refresh profile
final profileRefreshProvider = StateProvider<int>((ref) => 0);

final userPostsProvider =
    FutureProvider.family<List<PostModel>, String>(
        (ref, userId) async {
  ref.watch(profileRefreshProvider);
  return ref.watch(profileRepositoryProvider).getUserPosts(userId);
});

final blockedUsersProvider = FutureProvider.autoDispose<List<ProfileModel>>((ref) async {
  return ref.watch(profileRepositoryProvider).getBlockedUsers();
});

final mutedUsersProvider = FutureProvider.autoDispose<List<ProfileModel>>((ref) async {
  return ref.watch(profileRepositoryProvider).getMutedUsers();
});

final isBlockedProvider = Provider.family<bool, String>((ref, targetUserId) {
  final blockedUsersAsync = ref.watch(blockedUsersProvider);
  return blockedUsersAsync.when(
    data: (users) => users.any((u) => u.id == targetUserId),
    loading: () => false,
    error: (_, __) => false,
  );
});

// ──────── CHAT BLOCKS PROVIDERS (dùng bảng chat_blocks, độc lập với blocks) ───────────

/// Danh sách userId mình đã chặn chat.
final chatBlockedUserIdsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  return ref.watch(profileRepositoryProvider).getChatBlockedUserIds();
});

/// Bạn có đang chặn chat của [targetUserId] không?
final isChatBlockedProvider = Provider.family<bool, String>((ref, targetUserId) {
  final idsAsync = ref.watch(chatBlockedUserIdsProvider);
  return idsAsync.when(
    data: (ids) => ids.contains(targetUserId),
    loading: () => false,
    error: (_, __) => false,
  );
});

/// [targetUserId] có đang chặn chat của bạn không?
final isChatBlockedByProvider = FutureProvider.family<bool, String>((ref, targetUserId) async {
  if (targetUserId.isEmpty) return false;
  return ref.watch(profileRepositoryProvider).isChatBlockedByUser(targetUserId);
});
