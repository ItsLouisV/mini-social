import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../profile/domain/profile_model.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';

/// Stub class cho FailedMessage trên Web
class FailedMessage {
  int obxId = 0;
  late String localId;
  late String conversationId;
  late String senderId;
  String? content;
  String? mediaUrl;
  String messageType = 'text';
  String? replyToMessageId;
  late String createdAt;
  String? replyContent;
  String? replySenderId;
}

/// Stub class cho LocalChatRepository trên Web
class LocalChatRepository {
  LocalChatRepository(dynamic store);

  Future<List<ConversationModel>> getConversations(String currentUserId) async => [];
  Future<void> saveConversations(List<ConversationModel> convs) async {}
  Future<void> upsertConversation(ConversationModel conv) async {}

  Future<List<MessageModel>> getMessages(
    String conversationId, {
    int limit = 30,
    int offset = 0,
  }) async => [];

  Future<void> saveMessages(List<MessageModel> messages) async {}
  Future<void> insertMessage(MessageModel msg) async {}
  Future<void> deleteMessage(String messageId) async {}
  Future<void> pruneOldMessages(String conversationId, {int keepCount = 650}) async {}

  Future<ProfileModel?> getProfile(String userId) async => null;
  Future<void> saveProfile(ProfileModel profile) async {}
  Future<void> saveProfiles(List<ProfileModel> profiles) async {}

  Future<void> addFailedMessage(FailedMessage msg) async {}
  List<FailedMessage> getFailedMessages(String conversationId) => [];
  Future<void> removeFailedMessage(String localId) async {}
  int getFailedMessageCount(String conversationId) => 0;

  Future<void> clearAll() async {}
}

final localChatRepositoryProvider = Provider<LocalChatRepository?>((ref) {
  return null;
});
