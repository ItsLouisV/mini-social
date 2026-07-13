import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/objectbox_service.dart';
import '../../../objectbox.g.dart';
import '../../profile/domain/profile_model.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';
import 'collections/cached_conversation.dart';
import 'collections/cached_message.dart';
import 'collections/cached_profile.dart';
import 'collections/failed_message.dart';

export 'collections/failed_message.dart';

/// Repository thao tác với ObjectBox local database.
///
/// Cung cấp CRUD cho conversations, messages, profiles và failed messages
/// để hỗ trợ offline-first chat experience.
class LocalChatRepository {
  final Store _store;

  late final Box<CachedConversation> _convBox;
  late final Box<CachedMessage> _msgBox;
  late final Box<CachedProfile> _profileBox;
  late final Box<FailedMessage> _failedBox;

  LocalChatRepository(this._store) {
    _convBox = _store.box<CachedConversation>();
    _msgBox = _store.box<CachedMessage>();
    _profileBox = _store.box<CachedProfile>();
    _failedBox = _store.box<FailedMessage>();
  }

  // ── Conversations ──────────────────────────────────────────────────────────

  /// Lấy tất cả conversations từ cache, kèm profiles
  Future<List<ConversationModel>> getConversations(String currentUserId) async {
    final cached = _convBox.getAll();

    // Sort: lastMessageAt descending
    cached.sort((a, b) {
      final aTime = a.lastMessageAt ?? a.createdAt;
      final bTime = b.lastMessageAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    final conversations = <ConversationModel>[];
    for (final c in cached) {
      final otherUserId =
          c.participant1 == currentUserId ? c.participant2 : c.participant1;
      final cachedProfile = _getProfileById(otherUserId);
      conversations.add(_cachedConvToModel(c, otherUser: cachedProfile));
    }
    return conversations;
  }

  /// Lưu danh sách conversations (upsert theo id)
  Future<void> saveConversations(List<ConversationModel> convs) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final entities = convs.map((c) => _modelToCachedConv(c, now)).toList();
    _convBox.putMany(entities);
  }

  /// Lưu 1 conversation (upsert)
  Future<void> upsertConversation(ConversationModel conv) async {
    final now = DateTime.now().toUtc().toIso8601String();
    _convBox.put(_modelToCachedConv(conv, now));
  }

  // ── Messages ───────────────────────────────────────────────────────────────

  /// Lấy messages từ cache cho 1 conversation (descending, phân trang)
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    int limit = 30,
    int offset = 0,
  }) async {
    final query = _msgBox
        .query(CachedMessage_.conversationId.equals(conversationId))
        .order(CachedMessage_.createdAt, flags: Order.descending)
        .build();

    query
      ..offset = offset
      ..limit = limit;

    final results = query.find();
    query.close();

    return results.map(_cachedMsgToModel).toList();
  }

  /// Lưu danh sách messages (upsert theo id)
  Future<void> saveMessages(List<MessageModel> messages) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final entities = messages.map((m) => _modelToCachedMsg(m, now)).toList();
    _msgBox.putMany(entities);
  }

  /// Lưu 1 message (upsert)
  Future<void> insertMessage(MessageModel msg) async {
    final now = DateTime.now().toUtc().toIso8601String();
    _msgBox.put(_modelToCachedMsg(msg, now));
  }

  /// Xóa 1 message theo string id
  Future<void> deleteMessage(String messageId) async {
    final query = _msgBox.query(CachedMessage_.id.equals(messageId)).build();
    final result = query.findFirst();
    query.close();
    if (result != null) {
      _msgBox.remove(result.obxId);
    }
  }

  /// Giữ tối đa [keepCount] tin mới nhất per conversation, xóa tin cũ
  Future<void> pruneOldMessages(String conversationId,
      {int keepCount = 650}) async {
    final query = _msgBox
        .query(CachedMessage_.conversationId.equals(conversationId))
        .order(CachedMessage_.createdAt, flags: Order.descending)
        .build();

    final allMessages = query.find();
    query.close();

    if (allMessages.length <= keepCount) return;

    final toDelete = allMessages.sublist(keepCount);
    final ids = toDelete.map((m) => m.obxId).toList();
    _msgBox.removeMany(ids);
  }

  // ── Profiles ───────────────────────────────────────────────────────────────

  /// Lấy profile từ cache
  ProfileModel? _getProfileById(String userId) {
    final query =
        _profileBox.query(CachedProfile_.id.equals(userId)).build();
    final result = query.findFirst();
    query.close();
    if (result == null) return null;
    return _cachedProfileToModel(result);
  }

  /// Lấy profile (public API)
  Future<ProfileModel?> getProfile(String userId) async {
    return _getProfileById(userId);
  }

  /// Lưu 1 profile
  Future<void> saveProfile(ProfileModel profile) async {
    _profileBox.put(_modelToCachedProfile(profile));
  }

  /// Lưu nhiều profiles
  Future<void> saveProfiles(List<ProfileModel> profiles) async {
    _profileBox.putMany(profiles.map(_modelToCachedProfile).toList());
  }

  // ── Failed Messages ────────────────────────────────────────────────────────

  /// Lưu tin nhắn thất bại
  Future<void> addFailedMessage(FailedMessage msg) async {
    _failedBox.put(msg);
  }

  /// Lấy tất cả tin nhắn thất bại cho 1 conversation
  List<FailedMessage> getFailedMessages(String conversationId) {
    final query = _failedBox
        .query(FailedMessage_.conversationId.equals(conversationId))
        .order(FailedMessage_.createdAt)
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  /// Xóa tin nhắn thất bại (sau khi retry thành công)
  Future<void> removeFailedMessage(String localId) async {
    final query =
        _failedBox.query(FailedMessage_.localId.equals(localId)).build();
    final result = query.findFirst();
    query.close();
    if (result != null) {
      _failedBox.remove(result.obxId);
    }
  }

  /// Đếm tổng tin nhắn thất bại
  int getFailedMessageCount(String conversationId) {
    final query = _failedBox
        .query(FailedMessage_.conversationId.equals(conversationId))
        .build();
    final count = query.count();
    query.close();
    return count;
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  /// Xóa toàn bộ cache (khi logout)
  Future<void> clearAll() async {
    _convBox.removeAll();
    _msgBox.removeAll();
    _profileBox.removeAll();
    _failedBox.removeAll();
  }

  // ── Private Mappers ────────────────────────────────────────────────────────

  CachedConversation _modelToCachedConv(
      ConversationModel c, String syncedAt) {
    return CachedConversation()
      ..id = c.id
      ..participant1 = c.participant1
      ..participant2 = c.participant2
      ..lastMessage = c.lastMessage
      ..lastMessageAt = c.lastMessageAt?.toUtc().toIso8601String()
      ..lastMessageSenderId = c.lastMessageSenderId
      ..p1UnreadCount = c.p1UnreadCount
      ..p2UnreadCount = c.p2UnreadCount
      ..p1IsPinned = c.p1IsPinned
      ..p2IsPinned = c.p2IsPinned
      ..p1IsHidden = c.p1IsHidden
      ..p2IsHidden = c.p2IsHidden
      ..createdAt = c.createdAt.toUtc().toIso8601String()
      ..syncedAt = syncedAt;
  }

  ConversationModel _cachedConvToModel(
    CachedConversation c, {
    ProfileModel? otherUser,
  }) {
    return ConversationModel(
      id: c.id,
      participant1: c.participant1,
      participant2: c.participant2,
      lastMessage: c.lastMessage,
      lastMessageAt: c.lastMessageAt != null
          ? DateTime.parse(c.lastMessageAt!).toLocal()
          : null,
      createdAt: DateTime.parse(c.createdAt).toLocal(),
      lastMessageSenderId: c.lastMessageSenderId,
      p1UnreadCount: c.p1UnreadCount,
      p2UnreadCount: c.p2UnreadCount,
      p1IsPinned: c.p1IsPinned,
      p2IsPinned: c.p2IsPinned,
      p1IsHidden: c.p1IsHidden,
      p2IsHidden: c.p2IsHidden,
      otherUser: otherUser,
    );
  }

  CachedMessage _modelToCachedMsg(MessageModel m, String syncedAt) {
    return CachedMessage()
      ..id = m.id
      ..conversationId = m.conversationId
      ..senderId = m.senderId
      ..content = m.content
      ..mediaUrl = m.mediaUrl
      ..messageType = m.messageType
      ..isSeen = m.isSeen
      ..replyToMessageId = m.replyToMessageId
      ..callId = m.callId
      ..createdAt = m.createdAt.toUtc().toIso8601String()
      ..syncedAt = syncedAt
      ..replyContent = m.replyToMessage?.content
      ..replySenderId = m.replyToMessage?.senderId
      ..replyMessageType = m.replyToMessage?.messageType;
  }

  MessageModel _cachedMsgToModel(CachedMessage m) {
    MessageModel? replyTo;
    if (m.replyToMessageId != null && m.replySenderId != null) {
      replyTo = MessageModel(
        id: m.replyToMessageId!,
        conversationId: m.conversationId,
        senderId: m.replySenderId!,
        content: m.replyContent,
        messageType: m.replyMessageType ?? 'text',
        createdAt: DateTime.now(), // placeholder, chỉ dùng cho display
      );
    }

    return MessageModel(
      id: m.id,
      conversationId: m.conversationId,
      senderId: m.senderId,
      content: m.content,
      mediaUrl: m.mediaUrl,
      messageType: m.messageType,
      isSeen: m.isSeen,
      createdAt: DateTime.parse(m.createdAt).toLocal(),
      replyToMessageId: m.replyToMessageId,
      replyToMessage: replyTo,
      callId: m.callId,
    );
  }

  CachedProfile _modelToCachedProfile(ProfileModel p) {
    return CachedProfile()
      ..id = p.id
      ..username = p.username
      ..fullName = p.fullName
      ..avatarUrl = p.avatarUrl
      ..coverUrl = p.coverUrl
      ..createdAt = p.createdAt.toUtc().toIso8601String()
      ..syncedAt = DateTime.now().toUtc().toIso8601String();
  }

  ProfileModel _cachedProfileToModel(CachedProfile p) {
    return ProfileModel(
      id: p.id,
      username: p.username,
      fullName: p.fullName,
      avatarUrl: p.avatarUrl,
      coverUrl: p.coverUrl,
      createdAt: DateTime.parse(p.createdAt).toLocal(),
    );
  }
}

/// Provider cho LocalChatRepository.
/// Trả về null trên Web (không có ObjectBox).
final localChatRepositoryProvider = Provider<LocalChatRepository?>((ref) {
  final objectBox = ref.watch(objectBoxProvider);
  if (objectBox == null) return null;
  return LocalChatRepository(objectBox.store);
});
