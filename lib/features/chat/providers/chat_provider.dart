import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/chat_repository.dart';
import '../data/chat_sync_service.dart';
import '../data/local_chat_repository_exports.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';
import '../domain/pinned_message_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/connectivity_service.dart';
import 'hidden_chat_provider.dart' show secureStorageProvider;

// ── Repository Provider ───────────────────────────────────────────────────────

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseServiceProvider));
});

// ── Conversations Provider (Offline-First) ────────────────────────────────────

final conversationsProvider =
    StreamProvider.autoDispose<List<ConversationModel>>((ref) async* {
  final repo = ref.watch(chatRepositoryProvider);
  final local = ref.watch(localChatRepositoryProvider);
  final sync = ref.watch(chatSyncServiceProvider);
  final isOnline = ref.watch(isOnlineProvider);
  final currentUserId =
      ref.watch(supabaseServiceProvider).currentUserId;

  if (currentUserId == null) return;

  // ① Nếu có local cache → emit ngay lập tức (offline-first)
  if (local != null) {
    final cached = await local.getConversations(currentUserId);
    if (cached.isNotEmpty) {
      yield cached;
    }
  }

  // ② Nếu online → sync từ Supabase, emit kết quả mới
  if (isOnline && sync != null) {
    try {
      final synced = await sync.syncConversations();
      yield synced;
    } catch (_) {
      // Sync thất bại → giữ cache
    }
  } else if (isOnline) {
    // Không có local cache (Web) → fetch trực tiếp
    try {
      final convs = await repo.getConversations();
      yield convs;
    } catch (_) {}
  }

  // ③ Subscribe Supabase Realtime stream cho updates
  try {
    await for (final _ in repo.watchConversationsStream()) {
      try {
        final convs = await repo.getConversations();
        // Lưu vào cache nếu có
        if (local != null) {
          await local.saveConversations(convs);
          // Lưu profiles
          for (final conv in convs) {
            if (conv.otherUser != null) {
              await local.saveProfile(conv.otherUser!);
            }
          }
        }
        yield convs;
      } catch (e) {
        print('Error fetching updated conversations inside stream: $e');
      }
    }
  } catch (e) {
    print('Supabase Realtime watchConversationsStream error (WebSocket disconnected): $e');
    // Keep yielding last known state if possible
  }
});

// ── Chat Messages State ───────────────────────────────────────────────────────

/// Dữ liệu state của ChatMessagesNotifier
class ChatMessagesState {
  final List<MessageModel> messages;

  /// ID của tin nhắn cần scroll tới (sau khi UI rebuild xong).
  /// null = không cần scroll.
  final String? pendingScrollToId;

  /// Còn tin cũ hơn để load không
  final bool hasMore;

  /// Danh sách tin nhắn gửi thất bại (hiển thị ! như iMessage)
  final List<FailedMessage> failedMessages;

  const ChatMessagesState({
    this.messages = const [],
    this.pendingScrollToId,
    this.hasMore = true,
    this.failedMessages = const [],
  });

  ChatMessagesState copyWith({
    List<MessageModel>? messages,
    String? pendingScrollToId,
    bool clearPendingScroll = false,
    bool? hasMore,
    List<FailedMessage>? failedMessages,
  }) {
    return ChatMessagesState(
      messages: messages ?? this.messages,
      pendingScrollToId:
          clearPendingScroll ? null : (pendingScrollToId ?? this.pendingScrollToId),
      hasMore: hasMore ?? this.hasMore,
      failedMessages: failedMessages ?? this.failedMessages,
    );
  }
}

// ── ChatMessagesNotifier (Offline-First) ──────────────────────────────────────

class ChatMessagesNotifier
    extends AutoDisposeFamilyAsyncNotifier<ChatMessagesState, String> {
  RealtimeChannel? _channel;
  RealtimeChannel? _reactionChannel;
  bool _isLoadingMore = false;
  static const int _pageSize = 30;
  static const _uuid = Uuid();

  Future<Set<String>> _getDeletedMessageIds() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final raw = await storage.read(key: 'deleted_message_ids');
      if (raw == null) return {};
      return raw.split(',').toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> deleteMessageLocally(String messageId) async {
    try {
      final storage = ref.read(secureStorageProvider);
      final raw = await storage.read(key: 'deleted_message_ids');
      final currentIds = raw == null ? <String>{} : raw.split(',').toSet();
      currentIds.add(messageId);
      await storage.write(key: 'deleted_message_ids', value: currentIds.join(','));

      final current = state.valueOrNull;
      if (current != null) {
        final filtered = current.messages.where((m) => m.id != messageId).toList();
        state = AsyncData(current.copyWith(messages: filtered));
      }
    } catch (_) {}
  }

  Future<void> recallMessage(String messageId) async {
    // ① Optimistic update: cập nhật UI ngay lập tức
    final current = state.valueOrNull;
    if (current != null) {
      final updated = current.messages.map((m) {
        if (m.id == messageId) {
          return m.copyWith(
            messageType: 'recalled',
            content: 'Tin nhắn đã được thu hồi',
          );
        }
        return m;
      }).toList();
      state = AsyncData(current.copyWith(messages: updated));
    }

    // ② Sync ngầm với database (fire-and-forget)
    final repo = ref.read(chatRepositoryProvider);
    repo.recallMessage(messageId).catchError((_) {
      // Nếu lỗi, rollback về state cũ
      if (current != null) {
        state = AsyncData(current);
      }
    });
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    final repo = ref.read(chatRepositoryProvider);
    final userId = repo.currentUserId;
    if (userId == null) return;

    // ① Optimistic update ngay lập tức
    final current = state.valueOrNull;
    if (current != null) {
      final updated = current.messages.map((m) {
        if (m.id != messageId) return m;
        final newReactions = Map<String, List<String>>.from(
          m.reactions.map((k, v) => MapEntry(k, List<String>.from(v))),
        );
        final users = newReactions.putIfAbsent(emoji, () => []);
        if (users.contains(userId)) {
          users.remove(userId);
          if (users.isEmpty) newReactions.remove(emoji);
        } else {
          users.add(userId);
        }
        return m.copyWith(reactions: newReactions);
      }).toList();
      state = AsyncData(current.copyWith(messages: updated));
    }

    // ② Sync với database ngầm
    repo.toggleReaction(messageId, emoji).catchError((_) {
      // Rollback nếu lỗi
      if (current != null) state = AsyncData(current);
    });
  }

  Future<void> clearMyReactions(String messageId) async {
    final repo = ref.read(chatRepositoryProvider);
    final userId = repo.currentUserId;
    if (userId == null) return;

    // ① Optimistic update ngay lập tức: loại bỏ userId của mình khỏi tất cả các emoji
    final current = state.valueOrNull;
    if (current != null) {
      final updated = current.messages.map((m) {
        if (m.id != messageId) return m;
        final newReactions = Map<String, List<String>>.from(
          m.reactions.map((k, v) => MapEntry(k, List<String>.from(v))),
        );
        newReactions.forEach((emoji, users) {
          users.remove(userId);
        });
        newReactions.removeWhere((emoji, users) => users.isEmpty);
        return m.copyWith(reactions: newReactions);
      }).toList();
      state = AsyncData(current.copyWith(messages: updated));
    }

    // ② Sync với database ngầm
    repo.clearMyReactions(messageId).catchError((_) {
      // Rollback nếu lỗi
      if (current != null) state = AsyncData(current);
    });
  }

  @override
  Future<ChatMessagesState> build(String arg) async {
    final repo = ref.watch(chatRepositoryProvider);
    final local = ref.watch(localChatRepositoryProvider);
    final sync = ref.watch(chatSyncServiceProvider);
    final isOnline = ref.watch(isOnlineProvider);

    List<MessageModel> messages;
    bool hasMore;

    // ① Load từ local cache trước (instant) nếu có
    if (local != null && !kIsWeb) {
      final cached = await local.getMessages(arg, limit: _pageSize);
      if (cached.isNotEmpty) {
        final deletedIds = await _getDeletedMessageIds();
        messages = cached.where((m) => !deletedIds.contains(m.id)).toList();
        hasMore = cached.length >= _pageSize;

        // Emit cache ngay, sync ngầm phía dưới
        _syncInBackground(arg, sync, isOnline);
        _subscribeRealtime(arg, repo, local, sync);

        // Load failed messages
        final failed = local.getFailedMessages(arg);

        ref.onDispose(() => _channel?.unsubscribe());

        return ChatMessagesState(
          messages: messages,
          hasMore: hasMore,
          failedMessages: failed,
        );
      }
    }

    // ② Không có cache hoặc Web → load từ Supabase
    final fetched = await repo.getMessagesPaginated(arg, limit: _pageSize, offset: 0);
    final deletedIds = await _getDeletedMessageIds();
    messages = fetched.where((m) => !deletedIds.contains(m.id)).toList();
    hasMore = fetched.length >= _pageSize;

    // Lưu vào cache nếu có
    if (local != null && fetched.isNotEmpty) {
      await local.saveMessages(fetched);
    }

    _subscribeRealtime(arg, repo, local, sync);

    // Load failed messages
    final failed = local?.getFailedMessages(arg) ?? [];

    ref.onDispose(() {
      _channel?.unsubscribe();
      _reactionChannel?.unsubscribe();
    });

    return ChatMessagesState(
      messages: messages,
      hasMore: hasMore,
      failedMessages: failed,
    );
  }

  /// Sync ngầm — không block UI
  void _syncInBackground(
    String conversationId,
    ChatSyncService? sync,
    bool isOnline,
  ) {
    if (!isOnline || sync == null) return;

    Future.microtask(() async {
      try {
        final synced = await sync.syncMessages(conversationId);
        final current = state.valueOrNull;
        if (current == null || synced.isEmpty) return;

        final deletedIds = await _getDeletedMessageIds();
        // Merge: thay thế bằng synced messages nếu có nhiều hơn
        final existingIds = current.messages.map((m) => m.id).toSet();
        final newOnes = synced.where((m) => !existingIds.contains(m.id) && !deletedIds.contains(m.id)).toList();

        if (newOnes.isNotEmpty) {
          final merged = [...newOnes, ...current.messages];
          merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          state = AsyncData(current.copyWith(messages: merged));
        }
      } catch (_) {
        // Sync thất bại → giữ cache
      }
    });
  }

  Future<MessageModel> _fetchFullMessage(String id) async {
    final data = await ref
        .read(supabaseServiceProvider)
        .client
        .from('messages')
        .select('*, reply_to_message:reply_to_message_id(*)')
        .eq('id', id)
        .single();
    return MessageModel.fromJson(data);
  }

  /// Subscribe Supabase Realtime cho tin nhắn mới/cập nhật/xóa
  void _subscribeRealtime(
    String conversationId,
    ChatRepository repo,
    LocalChatRepository? local,
    ChatSyncService? sync,
  ) {
    try {
      _channel = ref
          .read(supabaseServiceProvider)
          .client
          .channel('messages:$conversationId');

      _channel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: (payload) async {
              final current = state.valueOrNull;
              if (current == null) return;

              final deletedIds = await _getDeletedMessageIds();

              if (payload.eventType == PostgresChangeEvent.insert) {
                final newId = payload.newRecord['id'] as String?;
                if (newId == null) return;
                if (current.messages.any((m) => m.id == newId)) return;
                if (deletedIds.contains(newId)) return;

                try {
                  final newMsg = await _fetchFullMessage(newId);
                  if (sync != null) {
                    await sync.cacheRealtimeMessage(newMsg);
                  }
                  state = AsyncData(current.copyWith(
                    messages: [newMsg, ...current.messages],
                  ));
                } catch (_) {
                  final newMsg = MessageModel.fromJson(payload.newRecord);
                  if (sync != null) {
                    await sync.cacheRealtimeMessage(newMsg);
                  }
                  state = AsyncData(current.copyWith(
                    messages: [newMsg, ...current.messages],
                  ));
                }
              } else if (payload.eventType == PostgresChangeEvent.update) {
                final updatedId = payload.newRecord['id'] as String?;
                if (updatedId == null) return;

                try {
                  final updatedMsg = await _fetchFullMessage(updatedId);
                  if (sync != null) {
                    await sync.cacheRealtimeMessage(updatedMsg);
                  }
                  final updatedList = current.messages.map((m) {
                    return m.id == updatedId ? updatedMsg : m;
                  }).toList();
                  state = AsyncData(current.copyWith(messages: updatedList));
                } catch (_) {
                  final updatedMsg = MessageModel.fromJson(payload.newRecord);
                  if (sync != null) {
                    await sync.cacheRealtimeMessage(updatedMsg);
                  }
                  final updatedList = current.messages.map((m) {
                    return m.id == updatedId ? updatedMsg : m;
                  }).toList();
                  state = AsyncData(current.copyWith(messages: updatedList));
                }
              } else if (payload.eventType == PostgresChangeEvent.delete) {
                final deletedId = payload.oldRecord['id'] as String?;
                if (deletedId == null) return;

                final updatedList = current.messages.where((m) => m.id != deletedId).toList();
                state = AsyncData(current.copyWith(messages: updatedList));
              }
            },
          )
          .subscribe((status, [error]) {
            if (status == RealtimeSubscribeStatus.channelError) {
              print('Supabase Realtime messages channel error: $error');
              if (error != null) {
                ref.read(supabaseServiceProvider).handleAuthError(error);
              }
            }
          });

    // Subscribe reaction changes cho conversation này
    _reactionChannel = ref
        .read(supabaseServiceProvider)
        .client
        .channel('reactions:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_reactions',
          callback: (payload) async {
            // Lấy message_id từ record
            final messageId = (payload.newRecord['message_id'] ??
                payload.oldRecord['message_id']) as String?;
            if (messageId == null) return;

            final current = state.valueOrNull;
            if (current == null) return;

            // Chỉ xử lý nếu message này đang trong state
            final msgIndex =
                current.messages.indexWhere((m) => m.id == messageId);
            if (msgIndex < 0) return;

            // Fetch lại reactions mới nhất từ DB
            try {
              final freshReactions =
                  await repo.getReactions(messageId);
              final updatedList = List<MessageModel>.from(current.messages);
              updatedList[msgIndex] = updatedList[msgIndex]
                  .copyWith(reactions: freshReactions);
              state = AsyncData(current.copyWith(messages: updatedList));
            } catch (_) {}
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.channelError) {
            print('Supabase Realtime reactions channel error: $error');
            if (error != null) {
              ref.read(supabaseServiceProvider).handleAuthError(error);
            }
          }
        });

    } catch (e) {
      print('Error subscribing to realtime messages: $e');
    }
  }

  // ── Phân trang load thêm tin cũ ──────────────────────────────────────────────

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    try {
      final repo = ref.read(chatRepositoryProvider);
      final local = ref.read(localChatRepositoryProvider);
      final isOnline = ref.read(isOnlineProvider);

      List<MessageModel> older;

      if (isOnline) {
        older = await repo.getMessagesPaginated(
          arg,
          limit: _pageSize,
          offset: current.messages.length,
        );
        if (local != null && older.isNotEmpty) {
          await local.saveMessages(older);
        }
      } else if (local != null) {
        older = await local.getMessages(
          arg,
          limit: _pageSize,
          offset: current.messages.length,
        );
      } else {
        older = [];
      }

      if (older.isEmpty) {
        state = AsyncData(current.copyWith(hasMore: false));
        return;
      }

      final deletedIds = await _getDeletedMessageIds();
      final existingIds = current.messages.map((m) => m.id).toSet();
      final newOnes = older.where((m) => !existingIds.contains(m.id) && !deletedIds.contains(m.id)).toList();

      state = AsyncData(current.copyWith(
        messages: [...current.messages, ...newOnes],
        hasMore: older.length >= _pageSize,
      ));
    } catch (_) {
    } finally {
      _isLoadingMore = false;
    }
  }

  // ── Nhảy tới tin nhắn (reply / pin) ──────────────────────────────────────────

  Future<void> jumpToMessage({
    required String messageId,
    required DateTime createdAt,
  }) async {
    if (_isLoadingMore) return;

    final current = state.valueOrNull;
    if (current == null) return;

    if (current.messages.any((m) => m.id == messageId)) {
      state = AsyncData(current.copyWith(pendingScrollToId: messageId));
      return;
    }

    _isLoadingMore = true;
    try {
      final repo = ref.read(chatRepositoryProvider);

      final window = await repo.getMessagesAroundDate(arg, createdAt);

      if (window.isEmpty) return;

      final deletedIds = await _getDeletedMessageIds();
      final existingIds = current.messages.map((m) => m.id).toSet();
      final newOnes =
          window.where((m) => !existingIds.contains(m.id) && !deletedIds.contains(m.id)).toList();

      if (newOnes.isEmpty) {
        state = AsyncData(current.copyWith(pendingScrollToId: messageId));
        return;
      }

      final merged = [...current.messages, ...newOnes];
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final local = ref.read(localChatRepositoryProvider);
      if (local != null) {
        await local.saveMessages(newOnes);
      }

      state = AsyncData(current.copyWith(
        messages: merged,
        pendingScrollToId: messageId,
      ));
    } catch (_) {
    } finally {
      _isLoadingMore = false;
    }
  }

  void clearPendingScroll() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearPendingScroll: true));
  }

  bool get isLoadingMore => _isLoadingMore;

  // ── Failed Messages (gửi thất bại → hiển thị ! như iMessage) ────────────────

  /// Thêm tin nhắn vào danh sách failed (khi gửi bị lỗi mạng)
  Future<void> addFailedMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String? mediaUrl,
    String messageType = 'text',
    String? replyToMessageId,
    String? replyContent,
    String? replySenderId,
  }) async {
    final local = ref.read(localChatRepositoryProvider);
    if (local == null) return;

    final failed = FailedMessage()
      ..localId = _uuid.v4()
      ..conversationId = conversationId
      ..senderId = senderId
      ..content = content
      ..mediaUrl = mediaUrl
      ..messageType = messageType
      ..replyToMessageId = replyToMessageId
      ..replyContent = replyContent
      ..replySenderId = replySenderId
      ..createdAt = DateTime.now().toUtc().toIso8601String();

    await local.addFailedMessage(failed);

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(
        failedMessages: local.getFailedMessages(conversationId),
      ));
    }
  }

  /// Retry gửi lại tin nhắn thất bại
  Future<bool> retryFailedMessage(String localId) async {
    final local = ref.read(localChatRepositoryProvider);
    if (local == null) return false;

    final failedMessages = local.getFailedMessages(arg);
    final failed = failedMessages.firstWhere(
      (m) => m.localId == localId,
      orElse: () => FailedMessage(),
    );
    if (failed.localId.isEmpty) return false;

    try {
      final repo = ref.read(chatRepositoryProvider);
      if (failed.messageType == 'image' && failed.mediaUrl != null) {
        await repo.sendImageMessage(
          failed.conversationId,
          XFile(failed.mediaUrl!),
          caption: failed.content != 'Đã gửi một ảnh' ? failed.content : null,
          replyToMessageId: failed.replyToMessageId,
        );
      } else {
        await repo.sendMessage(
          failed.conversationId,
          failed.content ?? '',
          messageType: failed.messageType,
          replyToMessageId: failed.replyToMessageId,
        );
      }

      // Gửi thành công → xóa khỏi failed list
      await local.removeFailedMessage(localId);

      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData(current.copyWith(
          failedMessages: local.getFailedMessages(arg),
        ));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Xóa tin nhắn thất bại
  Future<void> removeFailedMessage(String localId) async {
    final local = ref.read(localChatRepositoryProvider);
    if (local == null) return;

    await local.removeFailedMessage(localId);

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(
        failedMessages: local.getFailedMessages(arg),
      ));
    }
  }
}

final realtimeMessagesProvider = AsyncNotifierProvider.autoDispose
    .family<ChatMessagesNotifier, ChatMessagesState, String>(
  ChatMessagesNotifier.new,
);

// ── Total unread count ────────────────────────────────────────────────────────

final unreadMessagesCountProvider = StreamProvider.autoDispose<int>((ref) {
  return ref
      .watch(chatRepositoryProvider)
      .watchTotalUnreadMessagesCount()
      .handleError((err) {
    print('Supabase watchTotalUnreadMessagesCount stream error (WebSocket disconnected): $err');
  });
});

// ── Pinned Messages ───────────────────────────────────────────────────────────

class PinnedMessagesNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<PinnedMessageModel>, String> {
  RealtimeChannel? _channel;

  @override
  Future<List<PinnedMessageModel>> build(String arg) async {
    final repo = ref.watch(chatRepositoryProvider);
    final pinned = await repo.getPinnedMessages(arg);

    try {
      _channel = ref
          .read(supabaseServiceProvider)
          .client
          .channel('pinned_messages:$arg');

      _channel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'pinned_messages',
            callback: (payload) async {
              final convId = (payload.newRecord['conversation_id'] ??
                  payload.oldRecord['conversation_id']) as String?;

              if (convId == null || convId == arg) {
                try {
                  final updated = await repo.getPinnedMessages(arg);
                  state = AsyncValue.data(updated);
                } catch (_) {}
              }
            },
          )
          .subscribe((status, [error]) {
            if (status == RealtimeSubscribeStatus.channelError) {
              print('Supabase Realtime pinned messages channel error: $error');
              if (error != null) {
                ref.read(supabaseServiceProvider).handleAuthError(error);
              }
            }
          });
    } catch (e) {
      print('Error subscribing to realtime pinned messages: $e');
    }

    ref.onDispose(() => _channel?.unsubscribe());

    return pinned;
  }
}

final pinnedMessagesProvider = AsyncNotifierProvider.autoDispose
    .family<PinnedMessagesNotifier, List<PinnedMessageModel>, String>(
  PinnedMessagesNotifier.new,
);

// ── Chat Wallpaper Notifier & Provider ────────────────────────────────────────
//
// Primary storage: Supabase `conversation_settings` table (bền vững qua refresh).
// Offline cache : SharedPreferences (fallback khi chưa có kết nối).

class ChatWallpaperNotifier extends StateNotifier<Map<String, String>> {
  final Ref ref;
  ChatWallpaperNotifier(this.ref) : super({}) {
    _load();
  }

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  Future<void> _load() async {
    // ① Try SharedPreferences first for instant display
    await _loadFromPrefs();
    // ② Then fetch from Supabase and override
    await _loadFromSupabase();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wallpaperMap = <String, String>{};
      for (final key in prefs.getKeys()) {
        if (key.startsWith('chat_wallpaper_') &&
            !key.startsWith('chat_wallpaper_history_')) {
          final convId = key.substring('chat_wallpaper_'.length);
          final path = prefs.getString(key);
          if (path != null && !path.startsWith('blob:')) {
            wallpaperMap[convId] = path;
          } else if (path != null && path.startsWith('blob:')) {
            // Clean up invalid blob path from cache
            await prefs.remove(key);
          }
        }
      }
      if (wallpaperMap.isNotEmpty) {
        state = wallpaperMap;
      }
    } catch (e) {
      print('Error loading wallpapers from prefs: $e');
    }
  }

  Future<void> _loadFromSupabase() async {
    final uid = _userId;
    if (uid == null) return;
    try {
      final rows = await _client
          .from('conversation_settings')
          .select('conversation_id, wallpaper')
          .eq('user_id', uid);

      final wallpaperMap = <String, String>{};
      for (final row in (rows as List)) {
        final convId = row['conversation_id'] as String?;
        final path = row['wallpaper'] as String?;
        if (convId != null && path != null && path.isNotEmpty && !path.startsWith('blob:')) {
          wallpaperMap[convId] = path;
        }
      }
      if (wallpaperMap.isNotEmpty) {
        state = wallpaperMap;
        // Sync back to prefs as cache
        final prefs = await SharedPreferences.getInstance();
        for (final e in wallpaperMap.entries) {
          await prefs.setString('chat_wallpaper_${e.key}', e.value);
        }
      }
    } catch (e) {
      print('Error loading wallpapers from Supabase: $e');
    }
  }

  Future<void> setWallpaper(String conversationId, String path, {String? otherUserId}) async {
    // Update state immediately
    if (path.isEmpty) {
      state = Map<String, String>.from(state)..remove(conversationId);
    } else {
      state = Map<String, String>.from(state)..[conversationId] = path;
    }

    // Persist to SharedPreferences (cache)
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'chat_wallpaper_$conversationId';
      if (path.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, path);
      }
    } catch (e) {
      print('Error saving wallpaper to prefs: $e');
    }

    // Persist to Supabase (primary)
    final uid = _userId;
    if (uid != null && path.isNotEmpty) {
      try {
        final targetUserIds = [uid];
        if (otherUserId != null && otherUserId.isNotEmpty) {
          targetUserIds.add(otherUserId);
        }

        for (final targetUid in targetUserIds) {
          // Also update history in Supabase
          final existing = await _client
              .from('conversation_settings')
              .select('wallpaper_history')
              .eq('user_id', targetUid)
              .eq('conversation_id', conversationId)
              .maybeSingle();

          List<String> historyList = [];
          if (existing != null) {
            final raw = existing['wallpaper_history'];
            if (raw is List) historyList = List<String>.from(raw);
          }
          if (!historyList.contains(path)) {
            historyList.add(path);
          }

          await _client.from('conversation_settings').upsert({
            'user_id': targetUid,
            'conversation_id': conversationId,
            'wallpaper': path,
            'wallpaper_history': historyList,
          }, onConflict: 'user_id,conversation_id');
        }

        // Sync history state reactively
        ref
            .read(chatWallpaperHistoryProvider.notifier)
            .addWallpaperToHistoryState(conversationId, path);

        // Also persist history to prefs
        final prefs = await SharedPreferences.getInstance();
        final key = 'chat_wallpaper_history_$conversationId';
        final existingPrefs = prefs.getString(key);
        List<String> localHistory = [];
        if (existingPrefs != null) {
          try {
            localHistory = List<String>.from(jsonDecode(existingPrefs));
          } catch (_) {}
        }
        if (!localHistory.contains(path)) {
          localHistory.add(path);
          await prefs.setString(key, jsonEncode(localHistory));
        }
      } catch (e) {
        print('Error upserting wallpaper to Supabase: $e');
      }
    } else if (uid != null && path.isEmpty) {
      // Clear wallpaper but keep history
      try {
        final targetUserIds = [uid];
        if (otherUserId != null && otherUserId.isNotEmpty) {
          targetUserIds.add(otherUserId);
        }
        for (final targetUid in targetUserIds) {
          await _client.from('conversation_settings').upsert({
            'user_id': targetUid,
            'conversation_id': conversationId,
            'wallpaper': '',
          }, onConflict: 'user_id,conversation_id');
        }
      } catch (e) {
        print('Error clearing wallpaper from Supabase: $e');
      }
    }
  }
}

final chatWallpaperProvider =
    StateNotifierProvider<ChatWallpaperNotifier, Map<String, String>>((ref) {
  return ChatWallpaperNotifier(ref);
});

class ChatMuteNotifier extends StateNotifier<Map<String, bool>> {
  ChatMuteNotifier() : super({}) {
    _loadMutes();
  }

  Future<void> _loadMutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final muteMap = <String, bool>{};
      for (final key in keys) {
        if (key.startsWith('chat_mute_')) {
          final convId = key.substring('chat_mute_'.length);
          final muted = prefs.getBool(key);
          if (muted != null) {
            muteMap[convId] = muted;
          }
        }
      }
      state = muteMap;
    } catch (_) {}
  }

  Future<void> toggleMute(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'chat_mute_$conversationId';
      final current = state[conversationId] ?? false;
      final next = !current;
      await prefs.setBool(key, next);
      state = Map<String, bool>.from(state)..[conversationId] = next;
    } catch (_) {}
  }
}

final chatMuteProvider =
    StateNotifierProvider<ChatMuteNotifier, Map<String, bool>>((ref) {
  return ChatMuteNotifier();
});

// ── Chat Wallpaper History Notifier & Provider ──────────────────────────────
//
// Primary storage: Supabase `conversation_settings.wallpaper_history` (JSONB).
// Offline cache : SharedPreferences.

class ChatWallpaperHistoryNotifier
    extends StateNotifier<Map<String, List<String>>> {
  ChatWallpaperHistoryNotifier() : super({}) {
    _load();
  }

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  Future<void> _load() async {
    await _loadFromPrefs();
    await _loadFromSupabase();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, List<String>>{};
      for (final key in prefs.getKeys()) {
        if (key.startsWith('chat_wallpaper_history_')) {
          final convId = key.substring('chat_wallpaper_history_'.length);
          final json = prefs.getString(key);
          if (json != null) {
            try {
              final rawList = List<String>.from(jsonDecode(json));
              final cleanList = rawList.where((path) => !path.startsWith('blob:')).toList();
              if (cleanList.isNotEmpty) {
                map[convId] = cleanList;
              } else {
                await prefs.remove(key);
              }
            } catch (_) {}
          }
        }
      }
      if (map.isNotEmpty) state = map;
    } catch (_) {}
  }

  Future<void> _loadFromSupabase() async {
    final uid = _userId;
    if (uid == null) return;
    try {
      final rows = await _client
          .from('conversation_settings')
          .select('conversation_id, wallpaper_history')
          .eq('user_id', uid);

      final map = <String, List<String>>{};
      final prefs = await SharedPreferences.getInstance();
      for (final row in (rows as List)) {
        final convId = row['conversation_id'] as String?;
        final raw = row['wallpaper_history'];
        if (convId != null && raw is List) {
          final rawList = List<String>.from(raw);
          final cleanList = rawList.where((path) => !path.startsWith('blob:')).toList();
          if (cleanList.isNotEmpty) {
            map[convId] = cleanList;
            await prefs.setString(
              'chat_wallpaper_history_$convId',
              jsonEncode(cleanList),
            );
          }
        }
      }
      if (map.isNotEmpty) state = map;
    } catch (_) {}
  }

  void addWallpaperToHistoryState(String conversationId, String path) {
    final currentList = List<String>.from(state[conversationId] ?? []);
    if (!currentList.contains(path)) {
      currentList.add(path);
      state = Map<String, List<String>>.from(state)
        ..[conversationId] = currentList;
    }
  }

  Future<void> removeWallpaperFromHistory(
      String conversationId, String path) async {
    final currentList = List<String>.from(state[conversationId] ?? []);
    currentList.remove(path);

    state = Map<String, List<String>>.from(state)
      ..[conversationId] = currentList;

    // SharedPreferences cache
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'chat_wallpaper_history_$conversationId',
        jsonEncode(currentList),
      );
    } catch (_) {}

    // Supabase
    final uid = _userId;
    if (uid != null) {
      try {
        await _client.from('conversation_settings').upsert({
          'user_id': uid,
          'conversation_id': conversationId,
          'wallpaper_history': currentList,
        }, onConflict: 'user_id,conversation_id');
      } catch (_) {}
    }
  }

  Future<void> clearHistory(String conversationId) async {
    state = Map<String, List<String>>.from(state)..remove(conversationId);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('chat_wallpaper_history_$conversationId');
    } catch (_) {}

    final uid = _userId;
    if (uid != null) {
      try {
        await _client.from('conversation_settings').upsert({
          'user_id': uid,
          'conversation_id': conversationId,
          'wallpaper': '',
          'wallpaper_history': <String>[],
        }, onConflict: 'user_id,conversation_id');
      } catch (_) {}
    }
  }
}

final chatWallpaperHistoryProvider =
    StateNotifierProvider<ChatWallpaperHistoryNotifier,
        Map<String, List<String>>>((ref) {
  return ChatWallpaperHistoryNotifier();
});

// ── Chat Theme Color Notifier & Provider ───────────────────────────────────────

class ChatThemeColorNotifier extends StateNotifier<Map<String, String>> {
  ChatThemeColorNotifier() : super({}) {
    _loadThemes();
  }

  Future<void> _loadThemes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final themeMap = <String, String>{};
      for (final key in keys) {
        if (key.startsWith('chat_theme_')) {
          final convId = key.substring('chat_theme_'.length);
          final colorName = prefs.getString(key);
          if (colorName != null) {
            themeMap[convId] = colorName;
          }
        }
      }
      state = themeMap;
    } catch (_) {}
  }

  Future<void> setTheme(String conversationId, String colorName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'chat_theme_$conversationId';
      if (colorName.isEmpty) {
        await prefs.remove(key);
        final newState = Map<String, String>.from(state)..remove(conversationId);
        state = newState;
      } else {
        await prefs.setString(key, colorName);
        final newState = Map<String, String>.from(state)..[conversationId] = colorName;
        state = newState;
      }
    } catch (_) {}
  }
}

final chatThemeColorProvider =
    StateNotifierProvider<ChatThemeColorNotifier, Map<String, String>>((ref) {
  return ChatThemeColorNotifier();
});

// ── Chat Self Destruct Notifier & Provider ─────────────────────────────────────

class ChatSelfDestructNotifier extends StateNotifier<Map<String, int>> {
  ChatSelfDestructNotifier() : super({}) {
    _loadSelfDestructs();
  }

  Future<void> _loadSelfDestructs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final map = <String, int>{};
      for (final key in keys) {
        if (key.startsWith('chat_self_destruct_')) {
          final convId = key.substring('chat_self_destruct_'.length);
          final seconds = prefs.getInt(key);
          if (seconds != null) {
            map[convId] = seconds;
          }
        }
      }
      state = map;
    } catch (_) {}
  }

  Future<void> setSelfDestruct(String conversationId, int seconds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'chat_self_destruct_$conversationId';
      if (seconds <= 0) {
        await prefs.remove(key);
        final newState = Map<String, int>.from(state)..remove(conversationId);
        state = newState;
      } else {
        await prefs.setInt(key, seconds);
        final newState = Map<String, int>.from(state)..[conversationId] = seconds;
        state = newState;
      }
    } catch (_) {}
  }
}

final chatSelfDestructProvider =
    StateNotifierProvider<ChatSelfDestructNotifier, Map<String, int>>((ref) {
  return ChatSelfDestructNotifier();
});
