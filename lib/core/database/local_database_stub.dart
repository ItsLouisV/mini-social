/// Stub / fallback implementation of LocalDatabase.
/// This file is selected when neither dart.library.io nor dart.library.html
/// is available (e.g., during analysis or on unsupported platforms).
///
/// All methods throw [UnsupportedError] — they are never called at runtime.
class LocalDatabase {
  static Future<LocalDatabase> init() async {
    throw UnsupportedError('LocalDatabase is not supported on this platform');
  }

  bool get isNative => false;

  Future<void> saveMessages(
      String conversationId, List<Map<String, dynamic>> messages) async {}

  List<Map<String, dynamic>> getMessages(String conversationId,
      {int limit = 50, int offset = 0}) => [];

  Future<void> pruneConversationMessages(String conversationId,
      {int maxKeep = 100}) async {}

  Future<void> saveConversation(Map<String, dynamic> conv) async {}

  List<Map<String, dynamic>> getConversations() => [];

  Future<void> savePosts(List<Map<String, dynamic>> posts) async {}

  List<Map<String, dynamic>> getPosts({int limit = 20, int offset = 0}) => [];

  Future<void> saveProfile(Map<String, dynamic> profile) async {}

  Map<String, dynamic>? getProfile(String userId) => null;

  Future<void> saveNotifications(
      List<Map<String, dynamic>> notifications) async {}

  List<Map<String, dynamic>> getNotifications({int limit = 50}) => [];

  Future<void> saveSearchQuery(String query) async {}

  List<String> getSearchHistory({int limit = 10}) => [];

  Future<void> clearSearchHistory() async {}

  Future<void> enqueueSyncAction(
      String id, String actionType, Map<String, dynamic> payload) async {}

  List<Map<String, dynamic>> getSyncQueue() => [];

  Future<void> removeSyncAction(String id) async {}

  Future<void> saveSettings(Map<String, dynamic> settings) async {}

  Map<String, dynamic>? getSettings() => null;

  Future<void> clearAll() async {}
}
