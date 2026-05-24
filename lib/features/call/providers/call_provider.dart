import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/call_repository.dart';
import '../domain/call_model.dart';

/// Cung cấp instance của CallRepository
final callRepositoryProvider = Provider<CallRepository>((ref) {
  return CallRepository(Supabase.instance.client);
});

/// Theo dõi cuộc gọi đến cho current user (Đã sửa lỗi chết luồng)
final incomingCallProvider = StreamProvider<CallModel?>((ref) {
  final repo = ref.watch(callRepositoryProvider);

  // Sử dụng onAuthStateChange để tự động tạo lại Stream khi User ID thay đổi
  return Supabase.instance.client.auth.onAuthStateChange.asyncExpand((authState) {
    final currentUserId = authState.session?.user.id;
    
    if (currentUserId == null) {
      // Nếu chưa có session (chưa đăng nhập), trả về stream rỗng an toàn
      return Stream.value(null);
    }
    
    // Nếu có userId hợp lệ, kích hoạt Realtime Channel từ repository
    return repo.watchIncomingCall(currentUserId);
  });
});

/// Theo dõi trạng thái của 1 cuộc gọi cụ thể
final callStateProvider = StreamProvider.family<CallModel, String>((ref, callId) {
  final repo = ref.watch(callRepositoryProvider);
  return repo.watchCall(callId);
});

