import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/chat_repository.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';
import '../domain/pinned_message_model.dart';
import '../../../core/services/supabase_service.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseServiceProvider));
});

final conversationsProvider =
    StreamProvider.autoDispose<List<ConversationModel>>((ref) {
  return ref.watch(chatRepositoryProvider).watchConversations();
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

  const ChatMessagesState({
    this.messages = const [],
    this.pendingScrollToId,
    this.hasMore = true,
  });

  ChatMessagesState copyWith({
    List<MessageModel>? messages,
    String? pendingScrollToId,
    bool clearPendingScroll = false,
    bool? hasMore,
  }) {
    return ChatMessagesState(
      messages: messages ?? this.messages,
      pendingScrollToId:
          clearPendingScroll ? null : (pendingScrollToId ?? this.pendingScrollToId),
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

// ── ChatMessagesNotifier ──────────────────────────────────────────────────────

class ChatMessagesNotifier
    extends AutoDisposeFamilyAsyncNotifier<ChatMessagesState, String> {
  RealtimeChannel? _channel;
  bool _isLoadingMore = false;
  static const int _pageSize = 30;

  @override
  Future<ChatMessagesState> build(String arg) async {
    final repo = ref.watch(chatRepositoryProvider);

    // Load trang đầu: tin mới nhất, descending → index 0 là mới nhất
    final messages =
        await repo.getMessagesPaginated(arg, limit: _pageSize, offset: 0);
    final hasMore = messages.length >= _pageSize;

    // Subscribe realtime cho tin mới
    _channel = ref
        .watch(supabaseServiceProvider)
        .client
        .channel('messages:$arg');

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: arg,
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
              state = AsyncData(current.copyWith(
                messages: [newMsg, ...current.messages],
              ));
            } catch (_) {
              final newMsg = MessageModel.fromJson(payload.newRecord);
              state = AsyncData(current.copyWith(
                messages: [newMsg, ...current.messages],
              ));
            }
          },
        )
        .subscribe();

    ref.onDispose(() => _channel?.unsubscribe());

    return ChatMessagesState(messages: messages, hasMore: hasMore);
  }

  // ── Phân trang load thêm tin cũ ──────────────────────────────────────────────

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    try {
      final repo = ref.read(chatRepositoryProvider);
      final older = await repo.getMessagesPaginated(
        arg,
        limit: _pageSize,
        offset: current.messages.length,
      );

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

  /// Kiểm tra xem [messageId] đã có trong state chưa.
  /// Nếu có → set [pendingScrollToId] để UI scroll.
  /// Nếu chưa → fetch một "window" xung quanh [createdAt] rồi merge vào state,
  ///            sau đó set [pendingScrollToId].
  ///
  /// KHÔNG xoá toàn bộ state cũ — chỉ merge thêm.
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

      // Lấy window xung quanh tin: 25 tin trước + 10 tin sau createdAt
      final window = await repo.getMessagesAroundDate(arg, createdAt);

      if (window.isEmpty) return;

      // Merge: giữ lại toàn bộ state cũ, nối thêm những tin chưa có
      final existingIds = current.messages.map((m) => m.id).toSet();
      final newOnes =
          window.where((m) => !existingIds.contains(m.id)).toList();

      if (newOnes.isEmpty) {
        // Tin đã có (race condition) → scroll thôi
        state = AsyncData(current.copyWith(pendingScrollToId: messageId));
        return;
      }

      // Merge và sort theo thời gian (descending, giống order ban đầu)
      final merged = [...current.messages, ...newOnes];
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = AsyncData(current.copyWith(
        messages: merged,
        pendingScrollToId: messageId,
        // Giữ nguyên hasMore — ta không biết phía trên còn tin không
      ));
    } catch (_) {
      // Fallback: báo UI không tìm thấy bằng cách không set pendingScrollToId
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
            // INSERT: newRecord có conversation_id
            // DELETE: newRecord rỗng, chỉ có oldRecord
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

