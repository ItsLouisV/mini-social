import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/call_repository.dart';
import '../domain/call_model.dart';

/// Cung cấp instance của CallRepository
final callRepositoryProvider = Provider<CallRepository>((ref) {
  return CallRepository(Supabase.instance.client);
});

/// Theo dõi cuộc gọi đến cho current user
final incomingCallProvider = StreamProvider<CallModel?>((ref) {
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;
  if (currentUserId == null) return Stream.value(null);

  final repo = ref.watch(callRepositoryProvider);
  return repo.watchIncomingCall(currentUserId);
});

/// Theo dõi trạng thái của 1 cuộc gọi cụ thể
final callStateProvider = StreamProvider.family<CallModel, String>((ref, callId) {
  final repo = ref.watch(callRepositoryProvider);
  return repo.watchCall(callId);
});
