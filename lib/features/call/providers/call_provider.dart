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
  final repo = ref.watch(callRepositoryProvider);

  // Lấy userId ngay lập tức — không chờ auth event
  // Đây là nguyên nhân Android không nhận được cuộc gọi:
  // onAuthStateChange chỉ bắn khi login/logout, không bắn khi app khởi động bình thường
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;

  if (currentUserId == null) {
    return Stream.value(null);
  }

  return repo.watchIncomingCall(currentUserId);
});

/// Theo dõi trạng thái của 1 cuộc gọi cụ thể
final callStateProvider = StreamProvider.family<CallModel, String>((ref, callId) {
  final repo = ref.watch(callRepositoryProvider);
  return repo.watchCall(callId);
});