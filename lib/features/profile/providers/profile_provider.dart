import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/profile_repository.dart';
import '../domain/profile_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/isar_service.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  final isar = ref.watch(isarServiceProvider);
  return ProfileRepository(supabase, isar);
});

/// One shared channel for profile/follow changes. Previously every profile
/// card opened its own channel, so scrolling through avatars exhausted the
/// Realtime quota.
final profileRealtimeRevisionProvider = StreamProvider.autoDispose<int>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  final client = service.client;
  final controller = StreamController<int>();
  var revision = 0;
  Timer? debounce;

  void notify(PostgresChangePayload _) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), () {
      if (!controller.isClosed) controller.add(++revision);
    });
  }

  final channel = client
      .channel('profiles:shared')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'profiles',
        callback: notify,
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'follows',
        callback: notify,
      );

  channel.subscribe((status, [error]) {
    if (status == RealtimeSubscribeStatus.channelError) {
      unawaited(service.handleRealtimeError(error));
    }
  });

  ref.onDispose(() {
    debounce?.cancel();
    unawaited(client.removeChannel(channel));
    unawaited(controller.close());
  });
  controller.add(revision);
  return controller.stream;
});

final profileProvider = FutureProvider.autoDispose
    .family<ProfileModel, String>((ref, userId) async {
  if (userId.trim().isEmpty) {
    throw ArgumentError('Cannot fetch profile for an empty userId');
  }
  ref.watch(profileRealtimeRevisionProvider);

  return ref.watch(profileRepositoryProvider).getProfile(userId);
});

// Provider để invalidate / refresh profile
final profileRefreshProvider = StateProvider<int>((ref) => 0);

final userPostsProvider = FutureProvider.autoDispose
    .family<UserPostsData, String>((ref, userId) async {
  ref.watch(profileRefreshProvider);
  final supabase = ref.watch(supabaseServiceProvider).client;

  final channel = supabase.channel('public:user_posts_$userId');
  try {
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'posts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            ref.invalidateSelf();
          },
        )
        .subscribe();
  } catch (_) {}

  ref.onDispose(() {
    try {
      supabase.removeChannel(channel);
    } catch (_) {}
  });

  return ref.watch(profileRepositoryProvider).getUserPosts(userId);
});

final blockedUsersProvider =
    FutureProvider.autoDispose<List<ProfileModel>>((ref) async {
  return ref.watch(profileRepositoryProvider).getBlockedUsers();
});

final mutedUsersProvider =
    FutureProvider.autoDispose<List<ProfileModel>>((ref) async {
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
final chatBlockedUserIdsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  return ref.watch(profileRepositoryProvider).getChatBlockedUserIds();
});

/// Bạn có đang chặn chat của [targetUserId] không?
final isChatBlockedProvider =
    Provider.family<bool, String>((ref, targetUserId) {
  final idsAsync = ref.watch(chatBlockedUserIdsProvider);
  return idsAsync.when(
    data: (ids) => ids.contains(targetUserId),
    loading: () => false,
    error: (_, __) => false,
  );
});

/// [targetUserId] có đang chặn chat của bạn không?
final isChatBlockedByProvider =
    FutureProvider.family<bool, String>((ref, targetUserId) async {
  if (targetUserId.isEmpty) return false;
  return ref.watch(profileRepositoryProvider).isChatBlockedByUser(targetUserId);
});
