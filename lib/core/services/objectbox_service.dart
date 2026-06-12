import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../objectbox.g.dart';

/// Service quản lý ObjectBox database lifecycle.
///
/// Init 1 lần trong main(), dùng toàn app.
class ObjectBoxService {
  static ObjectBoxService? _instance;
  late final Store _store;

  ObjectBoxService._(this._store);

  /// Mở ObjectBox Store — gọi 1 lần trong main()
  static Future<ObjectBoxService> init() async {
    if (_instance != null) return _instance!;

    final Store store;
    if (kIsWeb) {
      // Web: không hỗ trợ ObjectBox → skip, dùng online-only
      throw UnsupportedError(
        'ObjectBox không hỗ trợ Web. Offline cache chỉ hoạt động trên mobile/desktop.',
      );
    } else {
      final dir = await getApplicationDocumentsDirectory();
      store = await openStore(directory: '${dir.path}/objectbox');
    }

    _instance = ObjectBoxService._(store);
    return _instance!;
  }

  /// Trả về ObjectBox Store instance
  Store get store => _store;

  /// Xóa toàn bộ data (khi logout)
  Future<void> clearAll() async {
    _store.box<dynamic>(); // Ensure store is open
    // Xóa từng box cụ thể thông qua LocalChatRepository
  }

  /// Đóng store
  void close() {
    _store.close();
    _instance = null;
  }

  /// Kiểm tra đã init chưa
  static bool get isInitialized => _instance != null;
}

/// Provider cho ObjectBox Store — chỉ dùng trên mobile/desktop.
/// Web sẽ không init ObjectBox, provider trả về null.
final objectBoxProvider = Provider<ObjectBoxService?>((ref) {
  // Được set trong main() thông qua ProviderScope overrides
  return null;
});
