import 'package:flutter_riverpod/flutter_riverpod.dart';
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

// Realtime messages stream
final realtimeMessagesProvider =
    StreamProvider.autoDispose.family<List<MessageModel>, String>(
        (ref, conversationId) {
  return ref.watch(chatRepositoryProvider).watchMessages(conversationId);
});
