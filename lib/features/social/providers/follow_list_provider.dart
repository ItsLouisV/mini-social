import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../profile/domain/profile_model.dart';
import '../../../shared/providers/supabase_provider.dart';
import 'follow_provider.dart';

final followersProvider = FutureProvider.family<List<ProfileModel>, String>((ref, userId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final repo = ref.watch(socialRepositoryProvider);

  final channel = supabase.channel('public:follows:followers_$userId');
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
    ).subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.channelError) {
        print('Supabase Realtime followers channel error: $error');
      }
    });
  } catch (e) {
    print('Error subscribing to realtime followers: $e');
  }

  ref.onDispose(() {
    try {
      supabase.removeChannel(channel);
    } catch (_) {}
  });

  final data = await repo.getFollowers(userId);
  return data.map((e) => ProfileModel.fromJson(e)).toList();
});

final followingProvider = FutureProvider.family<List<ProfileModel>, String>((ref, userId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final repo = ref.watch(socialRepositoryProvider);

  final channel = supabase.channel('public:follows:following_$userId');
  try {
    channel.onPostgresChanges(
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
    ).subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.channelError) {
        print('Supabase Realtime following channel error: $error');
      }
    });
  } catch (e) {
    print('Error subscribing to realtime following: $e');
  }

  ref.onDispose(() {
    try {
      supabase.removeChannel(channel);
    } catch (_) {}
  });

  final data = await repo.getFollowing(userId);
  return data.map((e) => ProfileModel.fromJson(e)).toList();
});
