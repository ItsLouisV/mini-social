import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

class HiddenChatNotifier extends AutoDisposeAsyncNotifier<bool> {
  static const _passcodeKey = 'hidden_chat_passcode';
  
  @override
  Future<bool> build() async {
    final storage = ref.watch(secureStorageProvider);
    final passcode = await storage.read(key: _passcodeKey);
    return passcode != null; // return true if passcode is set
  }

  Future<void> setPasscode(String passcode) async {
    final storage = ref.read(secureStorageProvider);
    await storage.write(key: _passcodeKey, value: passcode);
    state = const AsyncData(true);
  }

  Future<bool> verifyPasscode(String input) async {
    final storage = ref.read(secureStorageProvider);
    final passcode = await storage.read(key: _passcodeKey);
    return passcode == input;
  }

  Future<void> removePasscode() async {
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: _passcodeKey);
    state = const AsyncData(false);
  }
}

final hiddenChatProvider = AutoDisposeAsyncNotifierProvider<HiddenChatNotifier, bool>(() {
  return HiddenChatNotifier();
});
