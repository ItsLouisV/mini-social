import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stub class cho ObjectBoxService trên môi trường Web.
class ObjectBoxService {
  static Future<ObjectBoxService> init() async {
    throw UnsupportedError(
      'ObjectBox không hỗ trợ Web. Offline cache chỉ hoạt động trên mobile/desktop.',
    );
  }

  dynamic get store => null;

  Future<void> clearAll() async {}
  void close() {}
  static bool get isInitialized => false;
}

final objectBoxProvider = Provider<ObjectBoxService?>((ref) {
  return null;
});
