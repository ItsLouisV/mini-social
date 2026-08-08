import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'isar_service.dart';
import 'supabase_service.dart';

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final isarService = ref.watch(isarServiceProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return SyncEngine(isarService, supabaseService);
});

class SyncEngine {
  final LocalDatabase _db;
  final SupabaseService _supabaseService;
  StreamSubscription? _connectivitySub;
  bool _isSyncing = false;

  SyncEngine(this._db, this._supabaseService) {
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

  /// Push an offline action into the sync queue outbox
  Future<void> enqueueAction({
    required String actionType,
    required Map<String, dynamic> payload,
  }) async {
    final itemId = DateTime.now().microsecondsSinceEpoch.toString();
    await _db.enqueueSyncAction(itemId, actionType, payload);
    debugPrint('📥 [SyncEngine] Enqueued action: $actionType (ID: $itemId)');
    // Attempt processing immediately if online
    processQueue();
  }

  /// Process all pending sync queue items sequentially
  Future<void> processQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pendingItems = _db.getSyncQueue();

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
          await _db.removeSyncAction(itemId);
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
