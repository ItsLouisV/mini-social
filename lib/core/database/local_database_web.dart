import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive_flutter/hive_flutter.dart';

/// Web (browser) implementation of the local database backed by Hive + IndexedDB.
/// This file is ONLY compiled on web platforms (dart.library.html is available).
/// Isar and dart:ffi are never referenced here.
class LocalDatabase {
  Box? _messagesBox;
  Box? _conversationsBox;
  Box? _postsBox;
  Box? _profilesBox;
  Box? _notificationsBox;
  Box? _searchHistoryBox;
  Box? _syncQueueBox;
  Box? _settingsBox;

  LocalDatabase._();

  static Future<LocalDatabase> init() async {
    await Hive.initFlutter();
    final db = LocalDatabase._();
    db._messagesBox = await Hive.openBox('viora_web_messages');
    db._conversationsBox = await Hive.openBox('viora_web_conversations');
    db._postsBox = await Hive.openBox('viora_web_posts');
    db._profilesBox = await Hive.openBox('viora_web_profiles');
    db._notificationsBox = await Hive.openBox('viora_web_notifications');
    db._searchHistoryBox = await Hive.openBox('viora_web_search_history');
    db._syncQueueBox = await Hive.openBox('viora_web_sync_queue');
    db._settingsBox = await Hive.openBox('viora_web_settings');
    debugPrint('🌐⚡ [LocalDatabase] Web IndexedDB (Hive) initialized successfully');
    return db;
  }

  bool get isNative => false;

  // ── Messages ───────────────────────────────────────────────────────────────

  Future<void> saveMessages(
      String conversationId, List<Map<String, dynamic>> messages) async {
    if (_messagesBox == null) return;
    final data = <String, String>{};
    for (final m in messages) {
      final key = '${conversationId}_${m['id']}';
      data[key] = jsonEncode(m);
    }
    await _messagesBox!.putAll(data);
  }

  List<Map<String, dynamic>> getMessages(String conversationId,
      {int limit = 50, int offset = 0}) {
    if (_messagesBox == null) return [];
    final prefix = '${conversationId}_';
    final items = <Map<String, dynamic>>[];
    for (final key in _messagesBox!.keys) {
      if (key.toString().startsWith(prefix)) {
        final raw = _messagesBox!.get(key);
        if (raw != null) {
          items.add(jsonDecode(raw as String) as Map<String, dynamic>);
        }
      }
    }
    items.sort((a, b) {
      final aTime =
          DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
      final bTime =
          DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });
    return items.skip(offset).take(limit).toList();
  }

  Future<void> pruneConversationMessages(String conversationId,
      {int maxKeep = 100}) async {
    if (_messagesBox == null) return;
    final prefix = '${conversationId}_';
    final keys = _messagesBox!.keys
        .where((k) => k.toString().startsWith(prefix))
        .toList();
    if (keys.length > maxKeep) {
      final items = <MapEntry<dynamic, Map<String, dynamic>>>[];
      for (final k in keys) {
        final raw = _messagesBox!.get(k);
        if (raw != null) {
          items.add(
              MapEntry(k, jsonDecode(raw as String) as Map<String, dynamic>));
        }
      }
      items.sort((a, b) {
        final aTime =
            DateTime.tryParse(a.value['created_at']?.toString() ?? '') ??
                DateTime(1970);
        final bTime =
            DateTime.tryParse(b.value['created_at']?.toString() ?? '') ??
                DateTime(1970);
        return aTime.compareTo(bTime);
      });
      final toDelete =
          items.take(items.length - maxKeep).map((e) => e.key).toList();
      await _messagesBox!.deleteAll(toDelete);
    }
  }

  // ── Conversations ──────────────────────────────────────────────────────────

  Future<void> saveConversation(Map<String, dynamic> conv) async {
    if (_conversationsBox == null) return;
    await _conversationsBox!.put(conv['id'], jsonEncode(conv));
  }

  List<Map<String, dynamic>> getConversations() {
    if (_conversationsBox == null) return [];
    final items = <Map<String, dynamic>>[];
    for (final key in _conversationsBox!.keys) {
      final raw = _conversationsBox!.get(key);
      if (raw != null) {
        items.add(jsonDecode(raw as String) as Map<String, dynamic>);
      }
    }
    items.sort((a, b) {
      final aTime =
          DateTime.tryParse(a['last_message_at']?.toString() ?? '') ??
              DateTime(1970);
      final bTime =
          DateTime.tryParse(b['last_message_at']?.toString() ?? '') ??
              DateTime(1970);
      return bTime.compareTo(aTime);
    });
    return items;
  }

  // ── Posts ──────────────────────────────────────────────────────────────────

  Future<void> savePosts(List<Map<String, dynamic>> posts) async {
    if (_postsBox == null) return;
    final data = <String, String>{};
    for (final p in posts) {
      data[p['id'].toString()] = jsonEncode(p);
    }
    await _postsBox!.putAll(data);
  }

  List<Map<String, dynamic>> getPosts({int limit = 20, int offset = 0}) {
    if (_postsBox == null) return [];
    final items = <Map<String, dynamic>>[];
    for (final key in _postsBox!.keys) {
      final raw = _postsBox!.get(key);
      if (raw != null) {
        items.add(jsonDecode(raw as String) as Map<String, dynamic>);
      }
    }
    items.sort((a, b) {
      final aTime =
          DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
      final bTime =
          DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });
    return items.skip(offset).take(limit).toList();
  }

  // ── Profiles ───────────────────────────────────────────────────────────────

  Future<void> saveProfile(Map<String, dynamic> profile) async {
    if (_profilesBox == null) return;
    await _profilesBox!.put(profile['id'], jsonEncode(profile));
  }

  Map<String, dynamic>? getProfile(String userId) {
    if (_profilesBox == null) return null;
    final raw = _profilesBox!.get(userId);
    if (raw == null) return null;
    return jsonDecode(raw as String) as Map<String, dynamic>;
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  Future<void> saveNotifications(
      List<Map<String, dynamic>> notifications) async {
    if (_notificationsBox == null) return;
    final data = <String, String>{};
    for (final n in notifications) {
      data[n['id'].toString()] = jsonEncode(n);
    }
    await _notificationsBox!.putAll(data);
  }

  List<Map<String, dynamic>> getNotifications({int limit = 50}) {
    if (_notificationsBox == null) return [];
    final items = <Map<String, dynamic>>[];
    for (final key in _notificationsBox!.keys) {
      final raw = _notificationsBox!.get(key);
      if (raw != null) {
        items.add(jsonDecode(raw as String) as Map<String, dynamic>);
      }
    }
    items.sort((a, b) {
      final aTime =
          DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
      final bTime =
          DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });
    return items.take(limit).toList();
  }

  // ── Search History ─────────────────────────────────────────────────────────

  Future<void> saveSearchQuery(String query) async {
    if (_searchHistoryBox == null || query.trim().isEmpty) return;
    final clean = query.trim();
    await _searchHistoryBox!.put(
      clean.toLowerCase(),
      jsonEncode({
        'query': clean,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  List<String> getSearchHistory({int limit = 10}) {
    if (_searchHistoryBox == null) return [];
    final items = <Map<String, dynamic>>[];
    for (final key in _searchHistoryBox!.keys) {
      final raw = _searchHistoryBox!.get(key);
      if (raw != null) {
        items.add(jsonDecode(raw as String) as Map<String, dynamic>);
      }
    }
    items.sort((a, b) {
      final aTime =
          DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime(1970);
      final bTime =
          DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });
    return items.take(limit).map((e) => e['query'] as String).toList();
  }

  Future<void> clearSearchHistory() async {
    await _searchHistoryBox?.clear();
  }

  // ── Sync Queue ─────────────────────────────────────────────────────────────

  Future<void> enqueueSyncAction(
      String id, String actionType, Map<String, dynamic> payload) async {
    if (_syncQueueBox == null) return;
    await _syncQueueBox!.put(
      id,
      jsonEncode({
        'id': id,
        'actionType': actionType,
        'payload': payload,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  List<Map<String, dynamic>> getSyncQueue() {
    if (_syncQueueBox == null) return [];
    final items = <Map<String, dynamic>>[];
    for (final key in _syncQueueBox!.keys) {
      final raw = _syncQueueBox!.get(key);
      if (raw != null) {
        items.add(jsonDecode(raw as String) as Map<String, dynamic>);
      }
    }
    items.sort((a, b) {
      final aTime =
          DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
      final bTime =
          DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
      return aTime.compareTo(bTime);
    });
    return items;
  }

  Future<void> removeSyncAction(String id) async {
    await _syncQueueBox?.delete(id);
  }

  // ── Settings ───────────────────────────────────────────────────────────────

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    if (_settingsBox == null) return;
    await _settingsBox!.put('settings', jsonEncode(settings));
  }

  Map<String, dynamic>? getSettings() {
    if (_settingsBox == null) return null;
    final raw = _settingsBox!.get('settings');
    if (raw == null) return null;
    return jsonDecode(raw as String) as Map<String, dynamic>;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _messagesBox?.clear();
    await _conversationsBox?.clear();
    await _postsBox?.clear();
    await _profilesBox?.clear();
    await _notificationsBox?.clear();
    await _searchHistoryBox?.clear();
    await _syncQueueBox?.clear();
    await _settingsBox?.clear();
    debugPrint('🧹 [LocalDatabase] Cleared all Hive/IndexedDB data');
  }
}
