import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;
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
    } catch (_) {}
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
  bool _isLoadingMore = false;
  static const int _pageSize = 30;
  static const _uuid = Uuid();

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
        messages = cached;
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
    messages = await repo.getMessagesPaginated(arg, limit: _pageSize, offset: 0);
    hasMore = messages.length >= _pageSize;

    // Lưu vào cache nếu có
    if (local != null && messages.isNotEmpty) {
      await local.saveMessages(messages);
    }

    _subscribeRealtime(arg, repo, local, sync);

    // Load failed messages
    final failed = local?.getFailedMessages(arg) ?? [];

    ref.onDispose(() => _channel?.unsubscribe());

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

        // Merge: thay thế bằng synced messages nếu có nhiều hơn
        // (synced luôn là trang mới nhất từ server)
        final existingIds = current.messages.map((m) => m.id).toSet();
        final newOnes = synced.where((m) => !existingIds.contains(m.id)).toList();

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

  /// Subscribe Supabase Realtime cho tin nhắn mới
  void _subscribeRealtime(
    String conversationId,
    ChatRepository repo,
    LocalChatRepository? local,
    ChatSyncService? sync,
  ) {
    _channel = ref
        .watch(supabaseServiceProvider)
        .client
        .channel('messages:$conversationId');

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            final newId = payload.newRecord['id'] as String?;
            if (newId == null) return;

            final current = state.valueOrNull;
            if (current == null) return;

            // Dedup: bỏ qua nếu đã có
            if (current.messages.any((m) => m.id == newId)) return;

            try {
              final fullMsgData = await ref
                  .read(supabaseServiceProvider)
                  .client
                  .from('messages')
                  .select('*, reply_to_message:reply_to_message_id(*)')
                  .eq('id', newId)
                  .single();
              final newMsg = MessageModel.fromJson(fullMsgData);

              // Lưu vào local cache
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
          },
        )
        .subscribe();
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
        // Online: fetch từ Supabase
        older = await repo.getMessagesPaginated(
          arg,
          limit: _pageSize,
          offset: current.messages.length,
        );
        // Lưu vào cache
        if (local != null && older.isNotEmpty) {
          await local.saveMessages(older);
        }
      } else if (local != null) {
        // Offline: load từ local cache
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

      // Merge, dedup theo id
      final existingIds = current.messages.map((m) => m.id).toSet();
      final newOnes = older.where((m) => !existingIds.contains(m.id)).toList();

      state = AsyncData(current.copyWith(
        messages: [...current.messages, ...newOnes],
        hasMore: older.length >= _pageSize,
      ));
    } catch (_) {
      // bỏ qua lỗi mạng
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

    // Đã có trong state → chỉ cần scroll
    if (current.messages.any((m) => m.id == messageId)) {
      state = AsyncData(current.copyWith(pendingScrollToId: messageId));
      return;
    }

    _isLoadingMore = true;
    try {
      final repo = ref.read(chatRepositoryProvider);

      final window = await repo.getMessagesAroundDate(arg, createdAt);

      if (window.isEmpty) return;

      final existingIds = current.messages.map((m) => m.id).toSet();
      final newOnes =
          window.where((m) => !existingIds.contains(m.id)).toList();

      if (newOnes.isEmpty) {
        state = AsyncData(current.copyWith(pendingScrollToId: messageId));
        return;
      }

      final merged = [...current.messages, ...newOnes];
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Lưu vào cache
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

  /// Xoá pendingScrollToId sau khi UI đã xử lý xong
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
  return ref.watch(chatRepositoryProvider).watchTotalUnreadMessagesCount();
});

// ── Pinned Messages ───────────────────────────────────────────────────────────

class PinnedMessagesNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<PinnedMessageModel>, String> {
  RealtimeChannel? _channel;

  @override
  Future<List<PinnedMessageModel>> build(String arg) async {
    final repo = ref.watch(chatRepositoryProvider);
    final pinned = await repo.getPinnedMessages(arg);

    _channel = ref
        .watch(supabaseServiceProvider)
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
        .subscribe();

    ref.onDispose(() => _channel?.unsubscribe());

    return pinned;
  }
}

final pinnedMessagesProvider = AsyncNotifierProvider.autoDispose
    .family<PinnedMessagesNotifier, List<PinnedMessageModel>, String>(
  PinnedMessagesNotifier.new,
);
