import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';
import '../../profile/domain/profile_model.dart';
// import 'package:flutter/foundation.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/supabase_service.dart';

class ChatRepository {
  final SupabaseService _service;
  final _uuid = const Uuid();

  ChatRepository(this._service);

  SupabaseClient get _client => _service.client;
  String? get currentUserId => _service.currentUserId;

  // ── Conversations ──
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
        conversations.add(ConversationModel.fromJson(item, otherUser: otherUser));
      } catch (_) {
        conversations.add(conv);
      }
    }
    return conversations;
  }

  Stream<List<ConversationModel>> watchConversations() {
    return _client
        .from(SupabaseConstants.conversationsTable)
        .stream(primaryKey: ['id'])
        .asyncMap((_) => getConversations());
  }

  Future<ConversationModel> getOrCreateConversation(
      String otherUserId) async {
    final userId = currentUserId!;

    if (userId == otherUserId) {
      throw Exception('Không thể tạo cuộc trò chuyện với chính mình.');
    }

    // Check existing
    final existing = await _client
        .from(SupabaseConstants.conversationsTable)
        .select()
        .or('and(participant_1.eq.$userId,participant_2.eq.$otherUserId),and(participant_1.eq.$otherUserId,participant_2.eq.$userId)')
        .maybeSingle();

    if (existing != null) {
      return ConversationModel.fromJson(existing);
    }

    final p1 = userId.compareTo(otherUserId) < 0 ? userId : otherUserId;
    final p2 = userId.compareTo(otherUserId) < 0 ? otherUserId : userId;

    // Create new
    final created = await _client
        .from(SupabaseConstants.conversationsTable)
        .insert({
          'participant_1': p1,
          'participant_2': p2,
        })
        .select()
        .single();

    return ConversationModel.fromJson(created);
  }

  Stream<int> watchTotalUnreadMessagesCount() {
    final userId = currentUserId!;
    return _client
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
    });
  }

  // ── Messages ──
  Future<List<MessageModel>> getMessages(String conversationId,
      {int page = 0}) async {
    final data = await _client
        .from(SupabaseConstants.messagesTable)
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    return (data as List).map((e) => MessageModel.fromJson(e)).toList();
  }

  Future<MessageModel> sendMessage(
      String conversationId, String content) async {
    final data = await _client
        .from(SupabaseConstants.messagesTable)
        .insert({
          'conversation_id': conversationId,
          'sender_id': currentUserId,
          'content': content,
          'message_type': 'text',
        })
        .select()
        .single();

    // Update conversation's last message
    await _client
        .from(SupabaseConstants.conversationsTable)
        .update({
          'last_message': content,
          'last_message_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', conversationId);

    return MessageModel.fromJson(data);
  }

  Future<MessageModel> sendImageMessage(
      String conversationId, XFile imageFile) async {
    final userId = currentUserId!;
    final imageId = _uuid.v4();
    final ext = imageFile.name.split('.').last.toLowerCase();
    final path = '$userId/$conversationId/$imageId.$ext';

    final url = await _service.uploadFile(
      bucket: 'chat-images',
      path: path,
      file: imageFile,
    );

    final data = await _client
        .from(SupabaseConstants.messagesTable)
        .insert({
          'conversation_id': conversationId,
          'sender_id': userId,
          'content': null,
          'media_url': url,
          'message_type': 'image',
        })
        .select()
        .single();

    await _client
        .from(SupabaseConstants.conversationsTable)
        .update({
          'last_message': '📷 Hình ảnh',
          'last_message_at': DateTime.now().toUtc().toIso8601String(),
          'last_message_sender_id': userId,
        })
        .eq('id', conversationId);

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

  Stream<List<MessageModel>> watchMessages(String conversationId) {
    return _client
        .from(SupabaseConstants.messagesTable)
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((data) => data.map((e) => MessageModel.fromJson(e)).toList());
  }
}
