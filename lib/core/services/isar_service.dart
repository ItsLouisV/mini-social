import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../database/collections/isar_conversation.dart';
import '../database/collections/isar_message.dart';
import '../database/collections/isar_notification.dart';
import '../database/collections/isar_post.dart';
import '../database/collections/isar_post_draft.dart';
import '../database/collections/isar_profile.dart';
import '../database/collections/isar_search_history.dart';
import '../database/collections/isar_settings.dart';
import '../database/collections/isar_sync_queue.dart';

import 'hive_web_service.dart';

final isarServiceProvider = Provider<IsarService>((ref) {
  throw UnimplementedError('isarServiceProvider must be overridden in main()');
});

class IsarService {
  final Isar? isar;
  final HiveWebService? webService;

  IsarService(this.isar, {this.webService});

  static Future<IsarService> init() async {
    if (kIsWeb) {
      debugPrint('ℹ️ [IsarService] Web platform detected. Initializing Hive IndexedDB engine...');
      final web = await HiveWebService.init();
      return IsarService(null, webService: web);
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final instance = await Isar.open(
        [
          IsarMessageSchema,
          IsarConversationSchema,
          IsarPostSchema,
          IsarProfileSchema,
          IsarNotificationSchema,
          IsarSettingsSchema,
          IsarSearchHistorySchema,
          IsarPostDraftSchema,
          IsarSyncQueueSchema,
        ],
        directory: dir.path,
        name: 'viora_offline_db',
      );

      debugPrint('⚡ [IsarService] Isar DB initialized successfully on mobile disk');
      return IsarService(instance);
    } catch (e) {
      debugPrint('⚠️ [IsarService] Failed to initialize native Isar database: $e');
      final web = await HiveWebService.init();
      return IsarService(null, webService: web);
    }
  }

  /// Prune old messages for a conversation so only the latest [maxKeep] (50-100) messages remain cached.
  Future<void> pruneConversationMessages(String conversationId, {int maxKeep = 100}) async {
    if (isar == null) return;
    final count = await isar!.isarMessages
        .filter()
        .conversationIdEqualTo(conversationId)
        .count();

    if (count > maxKeep) {
      final oldMessages = await isar!.isarMessages
          .filter()
          .conversationIdEqualTo(conversationId)
          .sortByCreatedAt()
          .limit(count - maxKeep)
          .findAll();

      if (oldMessages.isNotEmpty) {
        await isar!.writeTxn(() async {
          final idsToDelete = oldMessages.map((e) => e.isarId).toList();
          await isar!.isarMessages.deleteAll(idsToDelete);
        });
        debugPrint('🗑️ [IsarService] Pruned ${oldMessages.length} old messages for conv: $conversationId');
      }
    }
  }

  /// Clear all cached data on logout or site clear
  Future<void> clearAllData() async {
    if (isar != null) {
      await isar!.writeTxn(() async {
        await isar!.clear();
      });
    }
    if (webService != null) {
      await webService!.clearAll();
    }
    debugPrint('🧹 [IsarService] Cleared all local database data');
  }
}
