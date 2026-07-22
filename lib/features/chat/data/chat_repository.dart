import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';
import '../domain/pinned_message_model.dart';
import '../../profile/domain/profile_model.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/supabase_service.dart';

class ChatRepository {
  final SupabaseService _service;
  final _uuid = const Uuid();

  ChatRepository(this._service);

  SupabaseClient get _client => _service.client;
  String? get currentUserId => _service.currentUserId;

  // ── Conversations ─────────────────────────────────────────────────────────────

  Future<List<ConversationModel>> getConversations() async {
    final userId = currentUserId!;
    final data = await _client
        .from(SupabaseConstants.conversationsTable)
        .select('*, last_message_sender:messages!fk_last_message(sender_id)')
        .or('participant_1.eq.$userId,participant_2.eq.$userId')
        .order('last_message_at', ascending: false);

    final conversations = <ConversationModel>[];
    for (final item in (data as List)) {
      final conv = ConversationModel.fromJson(item);
      final otherUserId = conv.getOtherUserId(userId);
      try {
        final profileData = await _client
            .from(SupabaseConstants.profilesTable)
            .select()
            .eq('id', otherUserId)
            .single();
        final otherUser = ProfileModel.fromJson(profileData);
        conversations
            .add(ConversationModel.fromJson(item, otherUser: otherUser));
      } catch (_) {
        conversations.add(conv);
      }
    }
    return conversations;
  }

  Stream<List<ConversationModel>> watchConversations() async* {
    try {
      final initialData = await getConversations();
      yield initialData;
    } catch (e) {
      print('Error fetching initial conversations: $e');
      rethrow;
    }

    final conversationsStream = _client
        .from(SupabaseConstants.conversationsTable)
        .stream(primaryKey: ['id'])
        .asyncMap((_) => getConversations())
        .handleError((err) {
          print('Supabase watchConversations stream error: $err');
          _service.handleAuthError(err);
        });

    try {
      await for (final conversations in conversationsStream) {
        yield conversations;
      }
    } catch (e) {
      print('Supabase watchConversations main stream error: $e');
    }
  }

  /// Stream thô — chỉ emit khi có thay đổi, không fetch models.
  /// Dùng bởi offline-first provider để trigger sync.
  Stream<void> watchConversationsStream() {
    return _client
        .from(SupabaseConstants.conversationsTable)
        .stream(primaryKey: ['id'])
        .map((_) {})
        .handleError((err) {
          print('Supabase watchConversationsStream error: $err');
          _service.handleAuthError(err);
        });
  }

  Future<ConversationModel> getOrCreateConversation(
      String otherUserId) async {
    final userId = currentUserId!;

    if (userId == otherUserId) {
      throw Exception('Không thể tạo cuộc trò chuyện với chính mình.');
    }

    final existing = await _client
        .from(SupabaseConstants.conversationsTable)
        .select()
        .or(
          'and(participant_1.eq.$userId,participant_2.eq.$otherUserId),'
          'and(participant_1.eq.$otherUserId,participant_2.eq.$userId)',
        )
        .maybeSingle();

    if (existing != null) {
      return ConversationModel.fromJson(existing);
    }

    final p1 =
        userId.compareTo(otherUserId) < 0 ? userId : otherUserId;
    final p2 =
        userId.compareTo(otherUserId) < 0 ? otherUserId : userId;

    final created = await _client
        .from(SupabaseConstants.conversationsTable)
        .insert({'participant_1': p1, 'participant_2': p2})
        .select()
        .single();

    return ConversationModel.fromJson(created);
  }

  Future<int> getTotalUnreadMessagesCount() async {
    final userId = currentUserId!;
    final data = await _client
        .from(SupabaseConstants.conversationsTable)
        .select('participant_1, participant_2, p1_unread_count, p2_unread_count')
        .or('participant_1.eq.$userId,participant_2.eq.$userId');
    
    int total = 0;
    for (var row in (data as List)) {
      if (row['participant_1'] == userId) {
        total += (row['p1_unread_count'] as int?) ?? 0;
      } else if (row['participant_2'] == userId) {
        total += (row['p2_unread_count'] as int?) ?? 0;
      }
    }
    return total;
  }

  Stream<int> watchTotalUnreadMessagesCount() async* {
    final userId = currentUserId!;
    try {
      final initialCount = await getTotalUnreadMessagesCount();
      yield initialCount;
    } catch (e) {
      print('Error fetching initial unread messages count: $e');
      yield 0;
    }

    final countStream = _client
        .from(SupabaseConstants.conversationsTable)
        .stream(primaryKey: ['id'])
        .map((data) {
          int total = 0;
          for (var row in data) {
            if (row['participant_1'] == userId) {
              total += (row['p1_unread_count'] as int?) ?? 0;
            } else if (row['participant_2'] == userId) {
              total += (row['p2_unread_count'] as int?) ?? 0;
            }
          }
          return total;
        })
        .handleError((err) {
          print('Supabase watchTotalUnreadMessagesCount stream error: $err');
          _service.handleAuthError(err);
        });

    try {
      await for (final count in countStream) {
        yield count;
      }
    } catch (e) {
      print('Supabase watchTotalUnreadMessagesCount main stream error: $e');
    }
  }

  // ── Conversation Actions ──────────────────────────────────────────────────────

  Future<void> togglePin(ConversationModel conv) async {
    final userId = currentUserId!;
    final isP1 = conv.participant1 == userId;
    final currentlyPinned = isP1 ? conv.p1IsPinned : conv.p2IsPinned;

    await _client.from(SupabaseConstants.conversationsTable).update({
      if (isP1) 'p1_is_pinned': !currentlyPinned,
      if (!isP1) 'p2_is_pinned': !currentlyPinned,
    }).eq('id', conv.id);
  }

  Future<void> toggleHide(ConversationModel conv) async {
    final userId = currentUserId!;
    final isP1 = conv.participant1 == userId;
    final currentlyHidden = isP1 ? conv.p1IsHidden : conv.p2IsHidden;

    await _client.from(SupabaseConstants.conversationsTable).update({
      if (isP1) 'p1_is_hidden': !currentlyHidden,
      if (!isP1) 'p2_is_hidden': !currentlyHidden,
    }).eq('id', conv.id);
  }

  Future<void> markAsRead(ConversationModel conv) async {
    final userId = currentUserId!;
    final isP1 = conv.participant1 == userId;

    await _client.from(SupabaseConstants.conversationsTable).update({
      if (isP1) 'p1_unread_count': 0,
      if (!isP1) 'p2_unread_count': 0,
    }).eq('id', conv.id);
  }

  Future<void> deleteConversation(String convId) async {
    await _client
        .from(SupabaseConstants.conversationsTable)
        .delete()
        .eq('id', convId);
  }

  // ── Messages ──────────────────────────────────────────────────────────────────

  /// Lấy toàn bộ tin nhắn (không phân trang) — chỉ dùng cho export / tìm kiếm.
  Future<List<MessageModel>> getMessages(String conversationId) async {
    final data = await _client
        .from(SupabaseConstants.messagesTable)
        .select('*, reply_to_message:reply_to_message_id(*), reactions:message_reactions(emoji, user_id)')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    return (data as List).map((e) => MessageModel.fromJson(e)).toList();
  }

  /// Load trang tin nhắn theo [offset].
  /// Kết quả trả về: index 0 = tin MỚI NHẤT (descending),
  /// phù hợp với ListView reverse: true.
  Future<List<MessageModel>> getMessagesPaginated(
    String conversationId, {
    required int limit,
    required int offset,
  }) async {
    final data = await _client
        .from(SupabaseConstants.messagesTable)
        .select('*, reply_to_message:reply_to_message_id(*), reactions:message_reactions(emoji, user_id)')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (data as List).map((e) => MessageModel.fromJson(e)).toList();
  }

  /// Lấy một "window" (cửa sổ) tin nhắn xung quanh [targetDate]:
  /// - [beforeCount] tin CŨ HƠN hoặc bằng targetDate
  /// - [afterCount] tin MỚI HƠN targetDate
  ///
  /// Dùng để jump-to-message (reply / pin) mà không cần xoá state cũ.
  Future<List<MessageModel>> getMessagesAroundDate(
    String conversationId,
    DateTime targetDate, {
    int beforeCount = 25,
    int afterCount = 10,
  }) async {
    final targetUtc = targetDate.toUtc().toIso8601String();

    // Lấy [beforeCount] tin cũ hơn hoặc bằng targetDate (bao gồm chính tin đó)
    final beforeFuture = _client
        .from(SupabaseConstants.messagesTable)
        .select('*, reply_to_message:reply_to_message_id(*)')
        .eq('conversation_id', conversationId)
        .lte('created_at', targetUtc) // less than or equal → tin CŨ HƠN
        .order('created_at', ascending: false)
        .limit(beforeCount);

    // Lấy [afterCount] tin mới hơn targetDate (context phía dưới)
    final afterFuture = _client
        .from(SupabaseConstants.messagesTable)
        .select('*, reply_to_message:reply_to_message_id(*)')
        .eq('conversation_id', conversationId)
        .gt('created_at', targetUtc) // greater than → tin MỚI HƠN
        .order('created_at', ascending: true)
        .limit(afterCount);

    final results = await Future.wait([beforeFuture, afterFuture]);

    final before =
        (results[0] as List).map((e) => MessageModel.fromJson(e)).toList();
    final after =
        (results[1] as List).map((e) => MessageModel.fromJson(e)).toList();

    // Kết hợp: before đang descending, after đang ascending
    // → merge rồi sort descending để nhất quán với getMessagesPaginated
    final all = [...before, ...after];
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  Future<MessageModel> sendMessage(
    String conversationId,
    String content, {
    String messageType = 'text',
    String? replyToMessageId,
  }) async {
    final data = await _client
        .from(SupabaseConstants.messagesTable)
        .insert({
          'conversation_id': conversationId,
          'sender_id': currentUserId,
          'content': content,
          'message_type': messageType,
          if (replyToMessageId != null)
            'reply_to_message_id': replyToMessageId,
        })
        .select()
        .single();

    await _client.from(SupabaseConstants.conversationsTable).update({
      'last_message': content,
      'last_message_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', conversationId);

    return MessageModel.fromJson(data);
  }

  Future<MessageModel> sendImageMessage(
    String conversationId,
    XFile image, {
    String? caption,
    String? replyToMessageId,
    String messageType = 'image',
  }) async {
    final ext = image.name.contains('.')
        ? image.name.split('.').last.toLowerCase()
        : 'jpg';
    final fileName = '$currentUserId/${_uuid.v4()}.$ext';
    final bytes = await image.readAsBytes();
    final contentType = ext == 'png'
        ? 'image/png'
        : (ext == 'gif' ? 'image/gif' : 'image/jpeg');

    await _client.storage
        .from(SupabaseConstants.messagesBucket)
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );

    final url = _client.storage
        .from(SupabaseConstants.messagesBucket)
        .getPublicUrl(fileName);

    final data = await _client
        .from(SupabaseConstants.messagesTable)
        .insert({
          'conversation_id': conversationId,
          'sender_id': currentUserId,
          'content': caption ?? 'Đã gửi một ảnh',
          'media_url': url,
          'message_type': messageType,
          if (replyToMessageId != null)
            'reply_to_message_id': replyToMessageId,
        })
        .select()
        .single();

    await _client.from(SupabaseConstants.conversationsTable).update({
      'last_message': 'Hình ảnh',
      'last_message_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', conversationId);

    return MessageModel.fromJson(data);
  }

  Future<MessageModel> sendVoiceMessage(
    String conversationId,
    List<int> audioBytes, {
    int? durationSeconds,
    String? replyToMessageId,
    String messageType = 'voice',
  }) async {
    final fileName = '$currentUserId/${_uuid.v4()}.m4a';

    try {
      await _client.storage
          .from(SupabaseConstants.messagesBucket)
          .uploadBinary(
            fileName,
            Uint8List.fromList(audioBytes),
            fileOptions: const FileOptions(contentType: 'audio/m4a'),
          );
    } catch (e) {
      print('Voice upload binary fallback: $e');
    }

    final url = _client.storage
        .from(SupabaseConstants.messagesBucket)
        .getPublicUrl(fileName);

    final dur = durationSeconds ?? 0;
    final durLabel =
        '${(dur ~/ 60).toString().padLeft(2, '0')}:${(dur % 60).toString().padLeft(2, '0')}';

    final data = await _client
        .from(SupabaseConstants.messagesTable)
        .insert({
          'conversation_id': conversationId,
          'sender_id': currentUserId,
          'content': 'Tin nhắn thoại ($durLabel)',
          'media_url': url,
          'message_type': messageType,
          if (replyToMessageId != null)
            'reply_to_message_id': replyToMessageId,
        })
        .select()
        .single();

    await _client.from(SupabaseConstants.conversationsTable).update({
      'last_message': 'Tin nhắn thoại ($durLabel)',
      'last_message_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', conversationId);

    return MessageModel.fromJson(data);
  }

  Future<void> markAsSeen(String conversationId) async {
    await _client
        .from(SupabaseConstants.messagesTable)
        .update({'is_seen': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', currentUserId!)
        .eq('is_seen', false);
  }

  // ── Pinned Messages ───────────────────────────────────────────────────────────

  Future<void> pinMessage(String conversationId, String messageId) async {
    await _client.from('pinned_messages').insert({
      'conversation_id': conversationId,
      'message_id': messageId,
      'pinned_by': currentUserId,
    });
  }

  Future<void> unpinMessage(String conversationId, String messageId) async {
    await _client
      .from('pinned_messages')
      .delete()
      .eq('conversation_id', conversationId)
      .eq('message_id', messageId);
  }

  Future<List<PinnedMessageModel>> getPinnedMessages(String conversationId) async {
    final data = await _client
      .from('pinned_messages')
      .select(
          '*, message:message_id(*, reply_to_message:reply_to_message_id(*))')
      .eq('conversation_id', conversationId)
      .order('pinned_at', ascending: false);

    return (data as List)
      .map((e) => PinnedMessageModel.fromJson(e))
      .toList();
  }

  Future<void> recallMessage(String messageId) async {
    await _client
        .from(SupabaseConstants.messagesTable)
        .update({
          'content': 'Tin nhắn đã thu hồi',
          'message_type': 'recalled',
          'media_url': null,
        })
        .eq('id', messageId);
  }

  Future<void> deleteMessage(String messageId) async {
    await _client
        .from(SupabaseConstants.messagesTable)
        .delete()
        .eq('id', messageId);
  }

  // ── Reactions ────────────────────────────────────────────────────────────────────

  /// Toggle emoji reaction cho tin nhắn:
  /// - Nếu user đã react emoji đó rồi → xóa (toggle off)
  /// - Nếu chưa → thêm mới
  Future<void> toggleReaction(String messageId, String emoji) async {
    final userId = currentUserId!;

    // Kiểm tra đã react chưa
    final existing = await _client
        .from('message_reactions')
        .select('id')
        .eq('message_id', messageId)
        .eq('user_id', userId)
        .eq('emoji', emoji)
        .maybeSingle();

    if (existing != null) {
      // Đã react → xóa
      await _client
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', userId)
          .eq('emoji', emoji);
    } else {
      // Chưa react → thêm
      await _client.from('message_reactions').insert({
        'message_id': messageId,
        'user_id': userId,
        'emoji': emoji,
      });
    }
  }

  /// Lấy tất cả reactions cho một message.
  Future<Map<String, List<String>>> getReactions(String messageId) async {
    final data = await _client
        .from('message_reactions')
        .select('emoji, user_id')
        .eq('message_id', messageId);

    final Map<String, List<String>> result = {};
    for (final r in (data as List)) {
      final emoji = r['emoji'] as String;
      final userId = r['user_id'] as String;
      result.putIfAbsent(emoji, () => []).add(userId);
    }
    return result;
  }

  /// Xóa toàn bộ emoji cảm xúc của mình trên tin nhắn này
  Future<void> clearMyReactions(String messageId) async {
    final userId = currentUserId!;
    await _client
        .from('message_reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', userId);
  }
}
