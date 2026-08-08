import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'collections/isar_message.dart';
import 'collections/isar_conversation.dart';
import 'collections/isar_post.dart';
import 'collections/isar_post_draft.dart';
import 'collections/isar_profile.dart';
import 'collections/isar_notification.dart';
import 'collections/isar_settings.dart';
import 'collections/isar_search_history.dart';
import 'collections/isar_sync_queue.dart';

/// Native (mobile/desktop) implementation of the local database backed by Isar.
/// This file is ONLY compiled on native platforms (dart.library.io is available).
/// dart2js / web builds will NEVER see this file or any Isar/FFI code.
class LocalDatabase {
  final Isar _isar;

  LocalDatabase._(this._isar);

  static Future<LocalDatabase> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [
        IsarMessageSchema,
        IsarConversationSchema,
        IsarPostSchema,
        IsarPostDraftSchema,
        IsarProfileSchema,
        IsarNotificationSchema,
        IsarSettingsSchema,
        IsarSearchHistorySchema,
        IsarSyncQueueSchema,
      ],
      directory: dir.path,
      name: 'viora_offline_db',
    );
    debugPrint('⚡ [LocalDatabase] Isar DB initialized on native disk: ${dir.path}');
    return LocalDatabase._(isar);
  }

  bool get isNative => true;

  // ── Messages ───────────────────────────────────────────────────────────────

  Future<void> saveMessages(
      String conversationId, List<Map<String, dynamic>> messages) async {
    await _isar.writeTxn(() async {
      for (final m in messages) {
        await _isar.isarMessages.put(IsarMessage(
          id: m['id'] as String,
          conversationId: conversationId,
          senderId: m['sender_id'] as String? ?? '',
          content: m['content'] as String? ?? '',
          messageType: m['message_type'] as String? ?? 'text',
          createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ??
              DateTime.now().toUtc(),
          replyToMessageId: m['reply_to_message_id'] as String?,
          status: 'sent',
          mediaUrlsJson: m['media_urls'] != null
              ? jsonEncode(m['media_urls'])
              : null,
          updatedAt: DateTime.now().toUtc(),
        ));
      }
    });
  }

  List<Map<String, dynamic>> getMessages(String conversationId,
      {int limit = 50, int offset = 0}) {
    final cached = _isar.isarMessages
        .filter()
        .conversationIdEqualTo(conversationId)
        .sortByCreatedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAllSync();
    return cached.map((m) {
      List<String> mediaUrls = const [];
      if (m.mediaUrlsJson != null && m.mediaUrlsJson!.isNotEmpty) {
        try {
          final decoded = jsonDecode(m.mediaUrlsJson!);
          if (decoded is List) mediaUrls = decoded.whereType<String>().toList();
        } catch (_) {}
      }
      return {
        'id': m.id,
        'conversation_id': m.conversationId,
        'sender_id': m.senderId,
        'content': m.content,
        'message_type': m.messageType,
        'created_at': m.createdAt.toIso8601String(),
        'reply_to_message_id': m.replyToMessageId,
        'status': m.status,
        'media_urls': mediaUrls,
      };
    }).toList();
  }

  Future<void> pruneConversationMessages(String conversationId,
      {int maxKeep = 100}) async {
    final count = await _isar.isarMessages
        .filter()
        .conversationIdEqualTo(conversationId)
        .count();
    if (count > maxKeep) {
      final oldMessages = await _isar.isarMessages
          .filter()
          .conversationIdEqualTo(conversationId)
          .sortByCreatedAt()
          .limit(count - maxKeep)
          .findAll();
      if (oldMessages.isNotEmpty) {
        await _isar.writeTxn(() async {
          await _isar.isarMessages
              .deleteAll(oldMessages.map((e) => e.isarId).toList());
        });
      }
    }
  }

  // ── Conversations ──────────────────────────────────────────────────────────

  Future<void> saveConversation(Map<String, dynamic> conv) async {
    await _isar.writeTxn(() async {
      await _isar.isarConversations.put(IsarConversation(
        id: conv['id'] as String,
        type: conv['type'] as String? ?? 'direct',
        name: conv['name'] as String?,
        avatarUrl: conv['avatar_url'] as String?,
        lastMessage: conv['last_message'] as String?,
        lastMessageAt:
            DateTime.tryParse(conv['last_message_at']?.toString() ?? ''),
        unreadCount: (conv['unread_count'] as int?) ?? 0,
        isPinned: (conv['is_pinned'] as bool?) ?? false,
        isMuted: (conv['is_muted'] as bool?) ?? false,
        isHidden: (conv['is_hidden'] as bool?) ?? false,
        otherUserId: conv['other_user_id'] as String?,
        otherUserName: conv['other_user_name'] as String?,
        otherUserAvatar: conv['other_user_avatar'] as String?,
        updatedAt: DateTime.now().toUtc(),
      ));
    });
  }

  List<Map<String, dynamic>> getConversations() {
    final cached = _isar.isarConversations.where().findAllSync();
    final result = cached.map((c) => <String, dynamic>{
          'id': c.id,
          'type': c.type,
          'name': c.name,
          'avatar_url': c.avatarUrl,
          'last_message': c.lastMessage,
          'last_message_at': c.lastMessageAt?.toIso8601String(),
          'unread_count': c.unreadCount,
          'is_pinned': c.isPinned,
          'is_muted': c.isMuted,
          'is_hidden': c.isHidden,
          'other_user_id': c.otherUserId,
          'other_user_name': c.otherUserName,
          'other_user_avatar': c.otherUserAvatar,
        }).toList();
    result.sort((a, b) {
      final aTime = DateTime.tryParse(a['last_message_at']?.toString() ?? '') ??
          DateTime(1970);
      final bTime = DateTime.tryParse(b['last_message_at']?.toString() ?? '') ??
          DateTime(1970);
      return bTime.compareTo(aTime);
    });
    return result;
  }

  // ── Posts ──────────────────────────────────────────────────────────────────

  Future<void> savePosts(List<Map<String, dynamic>> posts) async {
    await _isar.writeTxn(() async {
      for (final p in posts) {
        await _isar.isarPosts.put(IsarPost(
          id: p['id'] as String,
          authorId: p['user_id'] as String? ?? '',
          authorName: (p['profiles'] as Map<String, dynamic>?)?['full_name'] as String?,
          authorAvatar:
              (p['profiles'] as Map<String, dynamic>?)?['avatar_url'] as String?,
          content: p['caption'] as String? ?? '',
          imageUrls: const [],
          likesCount: (p['likes_count'] as int?) ?? 0,
          commentsCount: (p['comments_count'] as int?) ?? 0,
          isLiked: (p['is_liked'] as bool?) ?? false,
          createdAt: DateTime.tryParse(p['created_at']?.toString() ?? '') ??
              DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ));
      }
    });
  }

  List<Map<String, dynamic>> getPosts({int limit = 20, int offset = 0}) {
    final cached = _isar.isarPosts
        .where()
        .sortByCreatedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAllSync();
    return cached.map((p) => <String, dynamic>{
          'id': p.id,
          'user_id': p.authorId,
          'caption': p.content,
          'likes_count': p.likesCount,
          'comments_count': p.commentsCount,
          'is_liked': p.isLiked,
          'created_at': p.createdAt.toIso8601String(),
          'profiles': {
            'id': p.authorId,
            'full_name': p.authorName,
            'avatar_url': p.authorAvatar,
          },
        }).toList();
  }

  // ── Profiles ───────────────────────────────────────────────────────────────

  Future<void> saveProfile(Map<String, dynamic> profile) async {
    await _isar.writeTxn(() async {
      await _isar.isarProfiles.put(IsarProfile(
        id: profile['id'] as String,
        username: profile['username'] as String? ?? '',
        fullName: profile['full_name'] as String?,
        avatarUrl: profile['avatar_url'] as String?,
        bio: profile['bio'] as String?,
        followerCount: (profile['follower_count'] as int?) ?? 0,
        followingCount: (profile['following_count'] as int?) ?? 0,
        updatedAt: DateTime.now().toUtc(),
      ));
    });
  }

  Map<String, dynamic>? getProfile(String userId) {
    final p = _isar.isarProfiles
        .filter()
        .idEqualTo(userId)
        .findFirstSync();
    if (p == null) return null;
    return {
      'id': p.id,
      'username': p.username,
      'full_name': p.fullName,
      'avatar_url': p.avatarUrl,
      'bio': p.bio,
      'follower_count': p.followerCount,
      'following_count': p.followingCount,
    };
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  Future<void> saveNotifications(
      List<Map<String, dynamic>> notifications) async {
    await _isar.writeTxn(() async {
      for (final n in notifications) {
        final sender = n['profiles'] as Map<String, dynamic>?;
        await _isar.isarNotifications.put(IsarNotification(
          id: n['id'] as String,
          receiverId: n['receiver_id'] as String? ?? '',
          senderId: n['sender_id'] as String? ?? '',
          senderName: sender?['full_name'] as String? ?? sender?['username'] as String?,
          senderAvatar: sender?['avatar_url'] as String?,
          type: n['type'] as String? ?? 'other',
          content: n['content'] as String? ?? '',
          isRead: (n['is_read'] as bool?) ?? false,
          createdAt: DateTime.tryParse(n['created_at']?.toString() ?? '') ??
              DateTime.now().toUtc(),
        ));
      }
    });
  }

  List<Map<String, dynamic>> getNotifications({int limit = 50}) {
    final cached = _isar.isarNotifications
        .where()
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAllSync();
    return cached.map((n) => <String, dynamic>{
          'id': n.id,
          'receiver_id': n.receiverId,
          'sender_id': n.senderId,
          'sender_name': n.senderName,
          'sender_avatar': n.senderAvatar,
          'type': n.type,
          'content': n.content,
          'is_read': n.isRead,
          'created_at': n.createdAt.toIso8601String(),
          'profiles': {
            'id': n.senderId,
            'full_name': n.senderName,
            'avatar_url': n.senderAvatar,
          },
        }).toList();
  }

  // ── Search History ─────────────────────────────────────────────────────────

  Future<void> saveSearchQuery(String query) async {
    if (query.trim().isEmpty) return;
    final clean = query.trim();
    await _isar.writeTxn(() async {
      await _isar.isarSearchHistories.put(IsarSearchHistory(
        id: clean.toLowerCase(),
        query: clean,
        timestamp: DateTime.now().toUtc(),
      ));
    });
  }

  List<String> getSearchHistory({int limit = 10}) {
    final cached = _isar.isarSearchHistories
        .where()
        .sortByTimestampDesc()
        .limit(limit)
        .findAllSync();
    return cached.map((e) => e.query).toList();
  }

  Future<void> clearSearchHistory() async {
    await _isar.writeTxn(() async {
      await _isar.isarSearchHistories.clear();
    });
  }

  // ── Sync Queue ─────────────────────────────────────────────────────────────

  Future<void> enqueueSyncAction(
      String id, String actionType, Map<String, dynamic> payload) async {
    await _isar.writeTxn(() async {
      await _isar.isarSyncQueues.put(IsarSyncQueue(
        id: id,
        actionType: actionType,
        payloadJson: jsonEncode(payload),
        createdAt: DateTime.now().toUtc(),
      ));
    });
  }

  List<Map<String, dynamic>> getSyncQueue() {
    final items = _isar.isarSyncQueues
        .where()
        .sortByCreatedAt()
        .findAllSync();
    return items.map((item) => <String, dynamic>{
          'id': item.id,
          'actionType': item.actionType,
          'payload': jsonDecode(item.payloadJson),
          'created_at': item.createdAt.toIso8601String(),
        }).toList();
  }

  Future<void> removeSyncAction(String id) async {
    final item = _isar.isarSyncQueues
        .filter()
        .idEqualTo(id)
        .findFirstSync();
    if (item != null) {
      await _isar.writeTxn(() async {
        await _isar.isarSyncQueues.delete(item.isarId);
      });
    }
  }

  // ── Settings ───────────────────────────────────────────────────────────────

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await _isar.writeTxn(() async {
      for (final entry in settings.entries) {
        await _isar.isarSettings.put(IsarSettings(
          key: entry.key,
          value: entry.value?.toString() ?? '',
        ));
      }
    });
  }

  Map<String, dynamic>? getSettings() {
    final all = _isar.isarSettings.where().findAllSync();
    if (all.isEmpty) return null;
    return {for (final s in all) s.key: s.value};
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.clear();
    });
    debugPrint('🧹 [LocalDatabase] Cleared all Isar data');
  }
}
