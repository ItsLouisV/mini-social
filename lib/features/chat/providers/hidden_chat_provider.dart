import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../auth/providers/auth_provider.dart';
import 'chat_provider.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

class HiddenChatNotifier extends AutoDisposeAsyncNotifier<bool> {
  String? _cachedPasscodeHash;

  @override
  Future<bool> build() async {
    final repo = ref.watch(chatRepositoryProvider);
    _cachedPasscodeHash = await repo.getHiddenPasscode();
    return _cachedPasscodeHash != null && _cachedPasscodeHash!.isNotEmpty;
  }

  Future<void> setPasscode(String passcode) async {
    final repo = ref.read(chatRepositoryProvider);
    await repo.setHiddenPasscode(passcode);
    _cachedPasscodeHash = repo.hashPasscode(passcode);
    state = const AsyncData(true);
  }

  Future<bool> verifyPasscode(String input) async {
    final repo = ref.read(chatRepositoryProvider);
    return await repo.verifyHiddenPasscode(input);
  }

  Future<void> removePasscode() async {
    final repo = ref.read(chatRepositoryProvider);
    await repo.removeHiddenPasscode();
    _cachedPasscodeHash = null;
    state = const AsyncData(false);
  }
}

final hiddenChatProvider = AutoDisposeAsyncNotifierProvider<HiddenChatNotifier, bool>(() {
  return HiddenChatNotifier();
});

/// Đếm tổng số tin nhắn chưa đọc từ các cuộc trò chuyện đang bị ẩn
final unreadHiddenCountProvider = Provider.autoDispose<int>((ref) {
  final convs = ref.watch(conversationsProvider).valueOrNull ?? [];
  final currentUserId = ref.watch(currentUserIdProvider);
  if (currentUserId == null) return 0;

  int count = 0;
  for (final c in convs) {
    if (c.isHidden(currentUserId)) {
      count += c.getUnreadCount(currentUserId);
    }
  }
  return count;
});
