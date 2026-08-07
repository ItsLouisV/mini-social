import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import 'isar_service.dart';
import 'supabase_service.dart';
import '../database/collections/isar_sync_queue.dart';

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final isarService = ref.watch(isarServiceProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return SyncEngine(isarService, supabaseService);
});

class SyncEngine {
  final IsarService _isarService;
  final SupabaseService _supabaseService;
  StreamSubscription? _connectivitySub;
  bool _isSyncing = false;

  SyncEngine(this._isarService, this._supabaseService) {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected) {
        debugPrint('🌐 [SyncEngine] Reconnected to network. Triggering sync process...');
        processQueue();
      }
    });
  }

  /// Push an offline action into the IsarSyncQueue outbox
  Future<void> enqueueAction({
    required String actionType,
    required Map<String, dynamic> payload,
  }) async {
    final itemId = DateTime.now().microsecondsSinceEpoch.toString();

    if (_isarService.isar != null) {
      final queueItem = IsarSyncQueue(
        id: itemId,
        actionType: actionType,
        payloadJson: jsonEncode(payload),
        createdAt: DateTime.now().toUtc(),
      );
      await _isarService.isar!.writeTxn(() async {
        await _isarService.isar!.isarSyncQueues.put(queueItem);
      });
    } else if (_isarService.webService != null) {
      await _isarService.webService!.enqueueSyncAction(itemId, actionType, payload);
    } else {
      return;
    }

    debugPrint('📥 [SyncEngine] Enqueued action: $actionType (ID: $itemId)');
    
    // Attempt processing immediately if online
    processQueue();
  }

  /// Process all pending sync queue items sequentially
  Future<void> processQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pendingItems = <Map<String, dynamic>>[];
      if (_isarService.isar != null) {
        final rawItems = await _isarService.isar!.isarSyncQueues
            .where()
            .sortByCreatedAt()
            .findAll();
        for (final item in rawItems) {
          pendingItems.add({
            'isarId': item.isarId,
            'id': item.id,
            'actionType': item.actionType,
            'payload': jsonDecode(item.payloadJson),
          });
        }
      } else if (_isarService.webService != null) {
        pendingItems.addAll(_isarService.webService!.getSyncQueue());
      }

      if (pendingItems.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('🔄 [SyncEngine] Processing ${pendingItems.length} queued items...');

      for (final item in pendingItems) {
        final payload = item['payload'] as Map<String, dynamic>;
        final actionType = item['actionType'] as String;
        final itemId = item['id'] as String;
        bool success = false;

        try {
          switch (actionType) {
            case 'sendMessage':
              final convId = payload['conversation_id'] as String;
              final content = payload['content'] as String;
              final type = payload['message_type'] as String? ?? 'text';
              final replyId = payload['reply_to_message_id'] as String?;

              await _supabaseService.client.from('messages').insert({
                'conversation_id': convId,
                'sender_id': _supabaseService.currentUserId,
                'content': content,
                'message_type': type,
                if (replyId != null) 'reply_to_message_id': replyId,
              });
              success = true;
              break;

            case 'likePost':
              final postId = payload['post_id'] as String;
              await _supabaseService.client.from('post_likes').insert({
                'post_id': postId,
                'user_id': _supabaseService.currentUserId,
              });
              success = true;
              break;

            case 'unlikePost':
              final postId = payload['post_id'] as String;
              await _supabaseService.client
                  .from('post_likes')
                  .delete()
                  .eq('post_id', postId)
                  .eq('user_id', _supabaseService.currentUserId!);
              success = true;
              break;

            default:
              debugPrint('⚠️ [SyncEngine] Unknown actionType: $actionType');
              success = true; // remove unknown item
              break;
          }
        } catch (e) {
          debugPrint('❌ [SyncEngine] Failed to sync item $itemId ($actionType): $e');
          success = false;
        }

        if (success) {
          if (_isarService.isar != null && item['isarId'] != null) {
            await _isarService.isar!.writeTxn(() async {
              await _isarService.isar!.isarSyncQueues.delete(item['isarId'] as int);
            });
          } else if (_isarService.webService != null) {
            await _isarService.webService!.removeSyncAction(itemId);
          }
          debugPrint('✅ [SyncEngine] Successfully synced and removed item $itemId');
        } else {
          break;
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}
