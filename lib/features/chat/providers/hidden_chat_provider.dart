import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
