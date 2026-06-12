import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/domain/profile_model.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';
import 'chat_repository.dart';
import 'local_chat_repository.dart';
import '../providers/chat_provider.dart' show chatRepositoryProvider;

/// Service điều phối đồng bộ giữa Supabase (remote) và ObjectBox (local).
///
/// Flow:
/// 1. Load từ local cache → hiển thị ngay
/// 2. Fetch từ Supabase → merge vào local → update UI
/// 3. Realtime updates → save local + update UI
class ChatSyncService {
  final ChatRepository _remote;
  final LocalChatRepository _local;

  ChatSyncService(this._remote, this._local);

  // ── Sync Conversations ─────────────────────────────────────────────────────

  /// Fetch conversations từ Supabase → lưu vào local cache → return.
  ///
  /// Cũng lưu profiles của participants để hiển thị offline.
  Future<List<ConversationModel>> syncConversations() async {
    final remoteConvs = await _remote.getConversations();

    // Lưu conversations
    await _local.saveConversations(remoteConvs);

    // Lưu profiles của người chat cùng
    final profiles = <ProfileModel>[];
    for (final conv in remoteConvs) {
      if (conv.otherUser != null) {
        profiles.add(conv.otherUser!);
      }
    }
    if (profiles.isNotEmpty) {
      await _local.saveProfiles(profiles);
    }

    return remoteConvs;
  }

  // ── Sync Messages ──────────────────────────────────────────────────────────

  /// Fetch trang đầu tin nhắn từ Supabase → lưu vào local cache.
  Future<List<MessageModel>> syncMessages(
    String conversationId, {
    int limit = 30,
  }) async {
    final remoteMessages = await _remote.getMessagesPaginated(
      conversationId,
      limit: limit,
      offset: 0,
    );

    await _local.saveMessages(remoteMessages);

    // Prune tin cũ vượt giới hạn 650
    await _local.pruneOldMessages(conversationId);

    return remoteMessages;
  }

  /// Lưu 1 tin nhắn mới nhận qua realtime vào local cache.
  Future<void> cacheRealtimeMessage(MessageModel msg) async {
    await _local.insertMessage(msg);
  }

  /// Lưu conversation update từ realtime vào local cache.
  Future<void> cacheConversationUpdate(ConversationModel conv) async {
    await _local.upsertConversation(conv);
    if (conv.otherUser != null) {
      await _local.saveProfile(conv.otherUser!);
    }
  }
}

/// Provider cho ChatSyncService.
/// Trả về null trên Web (không có local cache).
final chatSyncServiceProvider = Provider<ChatSyncService?>((ref) {
  final local = ref.watch(localChatRepositoryProvider);
  if (local == null) return null;

  final remote = ref.watch(chatRepositoryProvider);
  return ChatSyncService(remote, local);
});

