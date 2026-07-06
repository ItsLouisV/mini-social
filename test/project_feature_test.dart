import 'package:flutter_test/flutter_test.dart';
import 'package:mini_social/features/chat/domain/conversation_model.dart';
import 'package:mini_social/features/chat/domain/message_model.dart';
import 'package:mini_social/features/profile/domain/profile_model.dart';

void main() {
  group('1. ConversationModel Tests', () {
    final mockJson = {
      'id': 'conv_123',
      'participant_1': 'user_A',
      'participant_2': 'user_B',
      'last_message': 'Xin chào!',
      'last_message_at': '2026-07-06T15:00:00.000Z',
      'created_at': '2026-07-06T10:00:00.000Z',
      'p1_unread_count': 5,
      'p2_unread_count': 0,
      'p1_is_pinned': true,
      'p2_is_pinned': false,
      'p1_is_hidden': false,
      'p2_is_hidden': true,
    };

    test('Should parse ConversationModel from JSON correctly', () {
      final conv = ConversationModel.fromJson(mockJson);

      expect(conv.id, equals('conv_123'));
      expect(conv.participant1, equals('user_A'));
      expect(conv.participant2, equals('user_B'));
      expect(conv.lastMessage, equals('Xin chào!'));
      expect(conv.p1UnreadCount, equals(5));
      expect(conv.p2UnreadCount, equals(0));
      expect(conv.p1IsPinned, isTrue);
      expect(conv.p2IsPinned, isFalse);
      expect(conv.p1IsHidden, isFalse);
      expect(conv.p2IsHidden, isTrue);
    });

    test('getOtherUserId should return the other user id correctly', () {
      final conv = ConversationModel.fromJson(mockJson);

      expect(conv.getOtherUserId('user_A'), equals('user_B'));
      expect(conv.getOtherUserId('user_B'), equals('user_A'));
    });

    test('getUnreadCount should return unread count for current user', () {
      final conv = ConversationModel.fromJson(mockJson);

      expect(conv.getUnreadCount('user_A'), equals(5));
      expect(conv.getUnreadCount('user_B'), equals(0));
    });

    test('isPinned & isHidden should match correct participant states', () {
      final conv = ConversationModel.fromJson(mockJson);

      expect(conv.isPinned('user_A'), isTrue);
      expect(conv.isPinned('user_B'), isFalse);

      expect(conv.isHidden('user_A'), isFalse);
      expect(conv.isHidden('user_B'), isTrue);
    });
  });

  group('2. MessageModel & Reactions Tests', () {
    test('Should parse message and reactions correctly from JSON', () {
      final mockJson = {
        'id': 'msg_001',
        'conversation_id': 'conv_123',
        'sender_id': 'user_A',
        'content': 'Ha Ha!',
        'media_url': null,
        'message_type': 'text',
        'is_seen': true,
        'created_at': '2026-07-06T15:00:00.000Z',
        'reply_to_message_id': null,
        'reactions': [
          {'emoji': '👍', 'user_id': 'user_B'},
          {'emoji': '👍', 'user_id': 'user_C'},
          {'emoji': '❤️', 'user_id': 'user_D'},
        ]
      };

      final msg = MessageModel.fromJson(mockJson);

      expect(msg.id, equals('msg_001'));
      expect(msg.isText, isTrue);
      expect(msg.isImage, isFalse);
      expect(msg.hasReactions, isTrue);
      expect(msg.reactions['👍'], containsAll(['user_B', 'user_C']));
      expect(msg.reactions['❤️'], contains('user_D'));
      expect(msg.reactions['👍']?.length, equals(2));
    });

    test('Should identify message types correctly', () {
      final now = DateTime.now();
      final textMsg = MessageModel(
        id: '1',
        conversationId: 'c',
        senderId: 's',
        messageType: 'text',
        createdAt: mockTime,
      );
      final imgMsg = MessageModel(
        id: '2',
        conversationId: 'c',
        senderId: 's',
        messageType: 'image',
        createdAt: mockTime,
      );
      final callMsg = MessageModel(
        id: '3',
        conversationId: 'c',
        senderId: 's',
        messageType: 'call_log',
        createdAt: mockTime,
      );
      final recalledMsg = MessageModel(
        id: '4',
        conversationId: 'c',
        senderId: 's',
        messageType: 'recalled',
        createdAt: mockTime,
      );

      expect(textMsg.isText, isTrue);
      expect(imgMsg.isImage, isTrue);
      expect(callMsg.isCall, isTrue);
      expect(recalledMsg.isRecalled, isTrue);
    });
  });

  group('3. Self-Destruct Filtering Logic Tests', () {
    test('Should filter out self-destructed messages based on limit', () {
      final now = DateTime.now();
      
      // Tin nhắn gửi từ 15 giây trước
      final oldMessage = MessageModel(
        id: 'old',
        conversationId: 'c1',
        senderId: 's1',
        createdAt: now.subtract(const Duration(seconds: 15)),
      );

      // Tin nhắn mới gửi 5 giây trước
      final newMessage = MessageModel(
        id: 'new',
        conversationId: 'c1',
        senderId: 's1',
        createdAt: now.subtract(const Duration(seconds: 5)),
      );

      final allMessages = [oldMessage, newMessage];
      const selfDestructSecs = 10; // Tự hủy sau 10 giây

      final displayedMessages = allMessages.where((m) {
        final age = now.difference(m.createdAt).inSeconds;
        return age < selfDestructSecs;
      }).toList();

      expect(displayedMessages.length, equals(1));
      expect(displayedMessages.first.id, equals('new'));
    });
  });

  group('4. ProfileModel parsing Tests', () {
    test('Should parse ProfileModel correctly from JSON', () {
      final json = {
        'id': 'user_X',
        'full_name': 'Louis V',
        'username': 'louisv',
        'avatar_url': 'https://domain.com/avatar.jpg',
        'created_at': '2026-07-06T12:00:00.000Z',
      };

      final profile = ProfileModel.fromJson(json);

      expect(profile.id, equals('user_X'));
      expect(profile.displayName, equals('Louis V'));
      expect(profile.username, equals('louisv'));
      expect(profile.avatarUrl, equals('https://domain.com/avatar.jpg'));
    });
  });
}

final mockTime = DateTime(2026, 7, 6, 12, 0, 0);
