import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'chat_provider.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

class HiddenChatNotifier extends AutoDisposeAsyncNotifier<bool> {
  String? _cachedPasscode;

  @override
  Future<bool> build() async {
    final repo = ref.watch(chatRepositoryProvider);
    _cachedPasscode = await repo.getHiddenPasscode();
    return _cachedPasscode != null && _cachedPasscode!.isNotEmpty;
  }

  Future<void> setPasscode(String passcode) async {
    final repo = ref.read(chatRepositoryProvider);
    await repo.setHiddenPasscode(passcode);
    _cachedPasscode = passcode;
    state = const AsyncData(true);
  }

  Future<bool> verifyPasscode(String input) async {
    if (_cachedPasscode != null && _cachedPasscode!.isNotEmpty) {
      return _cachedPasscode == input;
    }
    final repo = ref.read(chatRepositoryProvider);
    _cachedPasscode = await repo.getHiddenPasscode();
    return _cachedPasscode == input;
  }

  Future<void> removePasscode() async {
    final repo = ref.read(chatRepositoryProvider);
    await repo.removeHiddenPasscode();
    _cachedPasscode = null;
    state = const AsyncData(false);
  }
}

final hiddenChatProvider = AutoDisposeAsyncNotifierProvider<HiddenChatNotifier, bool>(() {
  return HiddenChatNotifier();
});
