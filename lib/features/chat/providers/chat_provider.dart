import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/chat_repository.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';
import '../../../core/services/supabase_service.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseServiceProvider));
});

final conversationsProvider = StreamProvider.autoDispose<List<ConversationModel>>((ref) {
  return ref.watch(chatRepositoryProvider).watchConversations();
});

// Realtime messages stream & pagination
class ChatMessagesNotifier extends AutoDisposeFamilyAsyncNotifier<List<MessageModel>, String> {
  RealtimeChannel? _channel;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  static const int _limit = 30;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  @override
  Future<List<MessageModel>> build(String arg) async {
    final repo = ref.watch(chatRepositoryProvider);
    
    // Initial fetch (tải tin nhắn mới nhất, trả về list đã đảo ngược so với DB, 
    // nhưng getMessagesPaginated đã trả về mới nhất trước (descending))
    // List này sẽ có index 0 là tin mới nhất, rất phù hợp với ListView reverse: true
    final messages = await repo.getMessagesPaginated(arg, limit: _limit, offset: 0);
    if (messages.length < _limit) _hasMore = false;

    // Lắng nghe realtime các tin nhắn mới
    _channel = ref.watch(supabaseServiceProvider).client.channel('public:messages:$arg');
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: arg,
      ),
      callback: (payload) async {
        try {
          // Lấy tin nhắn đầy đủ (bao gồm relation reply_to_message)
          final fullMsgData = await ref.read(supabaseServiceProvider).client
              .from('messages')
              .select('*, reply_to_message:reply_to_message_id(*)')
              .eq('id', payload.newRecord['id'])
              .single();
          final newMsg = MessageModel.fromJson(fullMsgData);
          
          final current = state.valueOrNull ?? [];
          if (!current.any((m) => m.id == newMsg.id)) {
            state = AsyncData([newMsg, ...current]);
          }
        } catch (_) {
          // Fallback nếu không fetch được relation
          final newMsg = MessageModel.fromJson(payload.newRecord);
          
          final current = state.valueOrNull ?? [];
          if (!current.any((m) => m.id == newMsg.id)) {
            state = AsyncData([newMsg, ...current]);
          }
        }
      },
    ).subscribe();

    ref.onDispose(() {
      _channel?.unsubscribe();
    });

    return messages;
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    _isLoadingMore = true;
    try {
      final current = state.valueOrNull ?? [];
      final repo = ref.read(chatRepositoryProvider);
      
      final olderMessages = await repo.getMessagesPaginated(arg, limit: _limit, offset: current.length);
      
      if (olderMessages.length < _limit) _hasMore = false;
      
      // olderMessages là những tin cũ hơn, sẽ được nối vào cuối mảng 
      // (vị trí cuối mảng hiển thị lên trên đỉnh màn hình do reverse: true)
      state = AsyncData([...current, ...olderMessages]);
    } catch (e) {
      // Bỏ qua lỗi mạng
    } finally {
      _isLoadingMore = false;
    }
  }
}

final realtimeMessagesProvider =
    AsyncNotifierProvider.autoDispose.family<ChatMessagesNotifier, List<MessageModel>, String>(
  ChatMessagesNotifier.new,
);

// Total unread messages count
final unreadMessagesCountProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(chatRepositoryProvider).watchTotalUnreadMessagesCount();
});
