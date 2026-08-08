import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:image_picker/image_picker.dart';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/conversation_model.dart';
import '../domain/conversation_member_model.dart';
import '../domain/message_model.dart';
import '../domain/pinned_message_model.dart';
import '../../profile/domain/profile_model.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/upstash_redis_service.dart';
import '../../../core/services/isar_service.dart';
import '../../../core/services/sync_engine.dart';
import '../../../core/utils/image_compressor.dart';

class ChatRepository {
  final SupabaseService _service;
  final IsarService? _isarService;
  final SyncEngine? _syncEngine;
  final UpstashRedisService? _upstashRedis;
  final _uuid = const Uuid();

  ChatRepository(
    this._service, [
    this._isarService,
    this._syncEngine,
    this._upstashRedis,
  ]);

  SupabaseClient get _client => _service.client;
  String? get currentUserId => _service.currentUserId;

  // ── Conversations ─────────────────────────────────────────────────────────────

  Future<List<ConversationModel>> getConversations() async {
    final userId = currentUserId!;
    try {
      final memberRows = await _client
          .from('conversation_members')
          .select('*, conversation:conversations(*, last_message_sender:messages!fk_last_message(sender_id))')
          .eq('user_id', userId);

      final conversations = <ConversationModel>[];
      for (final row in (memberRows as List)) {
        final convJson = row['conversation'] as Map<String, dynamic>?;
        if (convJson == null) continue;

        final myMemberState = ConversationMemberModel.fromJson(row);

        ProfileModel? otherUser;
        List<ConversationMemberModel>? groupMembers;

        if (convJson['type'] == 'direct' || convJson['type'] == null) {
          final p1 = convJson['participant_1'] as String?;
          final p2 = convJson['participant_2'] as String?;
          final otherUserId = p1 == userId ? p2 : p1;
          if (otherUserId != null && otherUserId.isNotEmpty) {
            try {
              final profileData = await _client
                  .from(SupabaseConstants.profilesTable)
                  .select()
                  .eq('id', otherUserId)
                  .single();
              otherUser = ProfileModel.fromJson(profileData);
            } catch (_) {}
          }
        } else if (convJson['type'] == 'group') {
          try {
            final mData = await _client
                .from('conversation_members')
                .select('*, profile:profiles(*)')
                .eq('conversation_id', convJson['id'] as String);
            groupMembers = (mData as List)
                .map((m) => ConversationMemberModel.fromJson(m))
                .toList();
          } catch (_) {}
        }

        final model = ConversationModel.fromJson(
          convJson,
          myMemberState: myMemberState,
          otherUser: otherUser,
          members: groupMembers,
        );
        conversations.add(model);

        // Sync conversation to local DB (platform-independent)
        await _isarService?.saveConversation({
          'id': model.id,
          'type': model.type,
          'name': model.name,
          'avatar_url': model.avatarUrl,
          'last_message': model.lastMessage,
          'last_message_at': model.lastMessageAt?.toIso8601String(),
          'unread_count': model.unreadCount,
          'is_pinned': model.isPinnedState,
          'is_muted': model.isMuted,
          'is_hidden': model.isHiddenState,
          'other_user_id': model.otherUser?.id,
          'other_user_name': model.otherUser?.fullName ?? model.otherUser?.username,
          'other_user_avatar': model.otherUser?.avatarUrl,
        });
      }

      conversations.sort((a, b) {
        final aDate = a.lastMessageAt ?? a.createdAt;
        final bDate = b.lastMessageAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });

      return conversations;
    } catch (e) {
      debugPrint('⚠️ [ChatRepository] Failed fetching online conversations, loading from local DB: $e');
      // Offline fallback: read from local DB
      if (_isarService != null) {
        final cached = _isarService!.getConversations();
        return cached.map((c) => ConversationModel(
          id: c['id'] as String,
          type: c['type'] as String? ?? 'direct',
          name: c['name'] as String?,
          avatarUrl: c['avatar_url'] as String?,
          lastMessage: c['last_message'] as String?,
          lastMessageAt: DateTime.tryParse(c['last_message_at']?.toString() ?? ''),
          createdAt: DateTime.tryParse(c['last_message_at']?.toString() ?? '') ?? DateTime.now(),
          myMemberState: ConversationMemberModel(
            id: 'offline_${c['id']}',
            conversationId: c['id'] as String,
            userId: currentUserId ?? '',
            unreadCount: (c['unread_count'] as int?) ?? 0,
            isPinned: (c['is_pinned'] as bool?) ?? false,
            isMuted: (c['is_muted'] as bool?) ?? false,
            isHidden: (c['is_hidden'] as bool?) ?? false,
          ),
          otherUser: c['other_user_id'] != null
              ? ProfileModel(
                  id: c['other_user_id'] as String,
                  username: c['other_user_name'] as String? ?? '',
                  fullName: c['other_user_name'] as String?,
                  avatarUrl: c['other_user_avatar'] as String?,
                  createdAt: DateTime.now(),
                )
              : null,
        )).toList();
      }
      rethrow;
    }
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

  /// Stream thô — chỉ emit khi có thay đổi (ở cả conversations và conversation_members), không fetch models.
  /// Dùng bởi offline-first provider để trigger sync.
  Stream<void> watchConversationsStream() {
    final stream1 = _client
        .from(SupabaseConstants.conversationsTable)
        .stream(primaryKey: ['id'])
        .map((_) {});

    final stream2 = _client
        .from('conversation_members')
        .stream(primaryKey: ['id'])
        .map((_) {});

    final controller = StreamController<void>();
    final s1 = stream1.listen((_) => controller.add(null), onError: (e) {});
    final s2 = stream2.listen((_) => controller.add(null), onError: (e) {});

    controller.onCancel = () {
      s1.cancel();
      s2.cancel();
    };

    return controller.stream.handleError((err) {
      print('Supabase watchConversationsStream error: $err');
      _service.handleAuthError(err);
    });
  }

  Future<ConversationModel> getOrCreateConversation(String otherUserId) async {
    final userId = currentUserId!;

    if (userId == otherUserId) {
      throw Exception('Không thể tạo cuộc trò chuyện với chính mình.');
    }

    final p1 = userId.compareTo(otherUserId) < 0 ? userId : otherUserId;
    final p2 = userId.compareTo(otherUserId) < 0 ? otherUserId : userId;

    final existing = await _client
        .from(SupabaseConstants.conversationsTable)
        .select()
        .eq('type', 'direct')
        .eq('participant_1', p1)
        .eq('participant_2', p2)
        .maybeSingle();

    Map<String, dynamic> convJson;
    if (existing != null) {
      convJson = existing;
    } else {
      convJson = await _client
          .from(SupabaseConstants.conversationsTable)
          .insert({
            'type': 'direct',
            'participant_1': p1,
            'participant_2': p2,
          })
          .select()
          .single();

      try {
        await _client.from('conversation_members').insert([
          {'conversation_id': convJson['id'], 'user_id': p1, 'role': 'owner'},
          {'conversation_id': convJson['id'], 'user_id': p2, 'role': 'member'},
        ]);
      } catch (e, stack) {
        debugPrint('⚠️ [ChatRepository] Lỗi chèn conversation_members cho direct chat: $e\n$stack');
      }
    }

    ConversationMemberModel? myMemberState;
    try {
      final memberData = await _client
          .from('conversation_members')
          .select()
          .eq('conversation_id', convJson['id'])
          .eq('user_id', userId)
          .maybeSingle();
      if (memberData != null) {
        myMemberState = ConversationMemberModel.fromJson(memberData);
      }
    } catch (_) {}

    ProfileModel? otherUser;
    try {
      final profileData = await _client
          .from(SupabaseConstants.profilesTable)
          .select()
          .eq('id', otherUserId)
          .single();
      otherUser = ProfileModel.fromJson(profileData);
    } catch (_) {}

    return ConversationModel.fromJson(
      convJson,
      myMemberState: myMemberState,
      otherUser: otherUser,
    );
  }

  Future<ConversationModel> createGroupConversation({
    required String name,
    XFile? avatar,
    required List<String> memberIds,
  }) async {
    final userId = currentUserId!;
    final allMembers = <String>{userId, ...memberIds}.toList();

    String? avatarUrl;
    if (avatar != null) {
      try {
        final ext = avatar.name.contains('.') ? avatar.name.split('.').last.toLowerCase() : 'jpg';
        final fileName = '$userId/group_avatars/${_uuid.v4()}.$ext';
        final compressedBytes = await ImageCompressor.compressXFile(avatar);
        await _client.storage.from(SupabaseConstants.messagesBucket).uploadBinary(
          fileName,
          compressedBytes,
          fileOptions: FileOptions(contentType: ext == 'png' ? 'image/png' : 'image/jpeg'),
        );
        avatarUrl = _client.storage.from(SupabaseConstants.messagesBucket).getPublicUrl(fileName);
      } catch (e, stack) {
        debugPrint('❌ [ChatRepository] Lỗi tải lên ảnh nhóm: $e\n$stack');
      }
    }

    final convId = _uuid.v4();

    // 1. Chèn bản ghi nhóm. KHÔNG còn cần participant_1/participant_2 —
    // conversation_members là nguồn dữ liệu thành viên duy nhất cho group.
    await _client.from(SupabaseConstants.conversationsTable).insert({
      'id': convId,
      'type': 'group',
      'name': name,
      'avatar_url': avatarUrl,
      'created_by': userId,
      'last_message': 'Đã tạo nhóm $name',
      'last_message_at': DateTime.now().toUtc().toIso8601String(),
    });

    // 2. Chèn thành viên. KHÔNG được nuốt lỗi ở đây — nếu thất bại, group
    // sẽ "mồ côi" (không ai là thành viên), nên phải rollback + throw.
    try {
      final memberRows = allMembers.map((mId) {
        return {
          'conversation_id': convId,
          'user_id': mId,
          'role': mId == userId ? 'owner' : 'member',
          'joined_at': DateTime.now().toUtc().toIso8601String(),
        };
      }).toList();

      await _client.from('conversation_members').insert(memberRows);
    } catch (e, stack) {
      debugPrint('❌ [ChatRepository] Lỗi chèn conversation_members, rollback: $e\n$stack');
      // Rollback: xoá conversation vừa tạo để không để lại "group ma"
      await _client.from(SupabaseConstants.conversationsTable).delete().eq('id', convId);
      throw Exception('Không thể tạo nhóm, vui lòng thử lại.');
    }

    // 3. Giờ đã là member thật sự trong conversation_members, RLS select() hợp lệ
    final created = await _client
      .from(SupabaseConstants.conversationsTable)
      .select()
      .eq('id', convId)
      .single();

    try {
      await sendMessage(convId, 'Đã tạo nhóm "$name"', messageType: 'system');
    } catch (e, stack) {
      debugPrint('❌ [ChatRepository] Lỗi chèn tin nhắn hệ thống tạo nhóm: $e\n$stack');
    }

    // Gửi thông báo song song thay vì tuần tự
    final notifyTargets = memberIds.where((mId) => mId != userId).toList();
    await Future.wait(notifyTargets.map((mId) async {
      try {
        try {
          await _client.from(SupabaseConstants.notificationsTable).insert({
            'receiver_id': mId,
            'sender_id': userId,
            'type': 'group_added',
            'content': 'Đã thêm bạn vào nhóm "$name"',
          });
        } catch (enumErr) {
          // Fallback nếu Postgres DB chưa add value 'group_added' vào notification_type enum
          await _client.from(SupabaseConstants.notificationsTable).insert({
            'receiver_id': mId,
            'sender_id': userId,
            'type': 'other',
            'content': 'Đã thêm bạn vào nhóm "$name"',
          });
        }
      } catch (e, stack) {
        debugPrint('❌ [ChatRepository] Lỗi gửi thông báo tới member $mId: $e\n$stack');
      }
    }));

    return ConversationModel.fromJson(created);
  }

  /// Cập nhật ảnh đại diện nhóm mới và tự động xóa ảnh cũ trên Supabase Storage để tiết kiệm dung lượng
  Future<void> updateGroupAvatar(String conversationId, XFile newAvatar) async {
    final userId = currentUserId!;

    final oldData = await _client
        .from(SupabaseConstants.conversationsTable)
        .select('avatar_url')
        .eq('id', conversationId)
        .maybeSingle();
    final oldAvatarUrl = (oldData?['avatar_url'] ?? oldData?['group_avatar_url']) as String?;

    final ext = newAvatar.name.contains('.') ? newAvatar.name.split('.').last.toLowerCase() : 'jpg';
    final fileName = '$userId/group_avatars/${_uuid.v4()}.$ext';
    final compressedBytes = await ImageCompressor.compressXFile(newAvatar);

    await _client.storage.from(SupabaseConstants.messagesBucket).uploadBinary(
          fileName,
          compressedBytes,
          fileOptions: FileOptions(contentType: ext == 'png' ? 'image/png' : 'image/jpeg'),
        );

    final newAvatarUrl = _client.storage.from(SupabaseConstants.messagesBucket).getPublicUrl(fileName);

    await _client.from(SupabaseConstants.conversationsTable).update({
      'avatar_url': newAvatarUrl,
    }).eq('id', conversationId);

    if (oldAvatarUrl != null && oldAvatarUrl.isNotEmpty) {
      try {
        final Uri uri = Uri.parse(oldAvatarUrl);
        final String path = uri.path;
        final String bucketPrefix = '/${SupabaseConstants.messagesBucket}/';
        if (path.contains(bucketPrefix)) {
          final String oldFilePath = path.substring(path.indexOf(bucketPrefix) + bucketPrefix.length);
          await _client.storage.from(SupabaseConstants.messagesBucket).remove([oldFilePath]);
          debugPrint('🗑️ [ChatRepository] Đã dọn dẹp xóa ảnh nhóm cũ khỏi Storage: $oldFilePath');
        }
      } catch (e, stack) {
        debugPrint('❌ [ChatRepository] Lỗi xóa ảnh nhóm cũ khỏi Storage: $e\n$stack');
      }
    }
  }

  /// Xóa ảnh đại diện nhóm (đặt về mặc định) và dọn dẹp Storage
  Future<void> deleteGroupAvatar(String conversationId) async {
    final oldData = await _client
        .from(SupabaseConstants.conversationsTable)
        .select('avatar_url')
        .eq('id', conversationId)
        .maybeSingle();
    final oldAvatarUrl = (oldData?['avatar_url'] ?? oldData?['group_avatar_url']) as String?;

    await _client.from(SupabaseConstants.conversationsTable).update({
      'avatar_url': null,
    }).eq('id', conversationId);

    if (oldAvatarUrl != null && oldAvatarUrl.isNotEmpty) {
      try {
        final Uri uri = Uri.parse(oldAvatarUrl);
        final String path = uri.path;
        final String bucketPrefix = '/${SupabaseConstants.messagesBucket}/';
        if (path.contains(bucketPrefix)) {
          final String oldFilePath = path.substring(path.indexOf(bucketPrefix) + bucketPrefix.length);
          await _client.storage.from(SupabaseConstants.messagesBucket).remove([oldFilePath]);
          debugPrint('🗑️ [ChatRepository] Đã dọn dẹp xóa ảnh nhóm khỏi Storage: $oldFilePath');
        }
      } catch (e, stack) {
        debugPrint('❌ [ChatRepository] Lỗi xóa ảnh nhóm khỏi Storage: $e\n$stack');
      }
    }
  }

  /// Đổi tên nhóm trò chuyện
  Future<void> updateGroupName(String conversationId, String newName) async {
    await _client.from(SupabaseConstants.conversationsTable).update({
      'name': newName,
    }).eq('id', conversationId);
  }

  /// Thêm các thành viên mới vào nhóm
  Future<void> addGroupMembers(String conversationId, List<String> newMemberIds) async {
    final memberRows = newMemberIds.map((mId) {
      return {
        'conversation_id': conversationId,
        'user_id': mId,
        'role': 'member',
        'joined_at': DateTime.now().toUtc().toIso8601String(),
      };
    }).toList();

    try {
      await _client.from('conversation_members').insert(memberRows);
    } catch (e, stack) {
      debugPrint('❌ [ChatRepository] Lỗi chèn thêm conversation_members: $e\n$stack');
    }
  }

  /// Rời khỏi nhóm
  Future<void> leaveGroup(String conversationId) async {
    final userId = currentUserId!;
    await removeGroupMember(conversationId, userId);
  }

  /// Giải tán nhóm trò chuyện (Dành cho Trưởng nhóm / Owner / Admin)
  Future<void> dissolveGroup(String conversationId) async {
    final userId = currentUserId;

    Map<String, dynamic>? groupData;
    try {
      groupData = await _client
          .from(SupabaseConstants.conversationsTable)
          .select('name, avatar_url, created_by')
          .eq('id', conversationId)
          .maybeSingle();
    } catch (e) {
      debugPrint('⚠️ [ChatRepository] Lỗi lấy thông tin nhóm để giải tán: $e');
    }

    final groupName = (groupData?['name'] ?? groupData?['group_name']) as String? ?? 'Nhóm trò chuyện';
    final avatarUrl = (groupData?['avatar_url'] ?? groupData?['group_avatar_url']) as String?;

    List<String> memberIds = [];
    try {
      final membersData = await _client
          .from('conversation_members')
          .select('user_id')
          .eq('conversation_id', conversationId);
      memberIds = (membersData as List).map((m) => m['user_id'] as String).toList();
    } catch (_) {}

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      try {
        final Uri uri = Uri.parse(avatarUrl);
        final String path = uri.path;
        final String bucketPrefix = '/${SupabaseConstants.messagesBucket}/';
        if (path.contains(bucketPrefix)) {
          final String filePath = path.substring(path.indexOf(bucketPrefix) + bucketPrefix.length);
          await _client.storage.from(SupabaseConstants.messagesBucket).remove([filePath]);
          debugPrint('🗑️ [ChatRepository] Đã xóa ảnh đại diện nhóm khỏi Storage: $filePath');
        }
      } catch (e) {
        debugPrint('⚠️ [ChatRepository] Lỗi dọn dẹp avatar nhóm: $e');
      }
    }

    try {
      await _client.from(SupabaseConstants.conversationsTable).delete().eq('id', conversationId);
    } catch (e, stack) {
      debugPrint('❌ [ChatRepository] Lỗi xóa bản ghi conversation nhóm: $e\n$stack');
      rethrow;
    }

    if (userId != null) {
      for (final mId in memberIds) {
        if (mId == userId) continue;
        try {
          try {
            await _client.from(SupabaseConstants.notificationsTable).insert({
              'receiver_id': mId,
              'sender_id': userId,
              'type': 'group_dissolved',
              'content': 'Trưởng nhóm đã giải tán nhóm "$groupName". Bạn không thể truy cập vào nhóm này nữa',
            });
          } catch (_) {
            await _client.from(SupabaseConstants.notificationsTable).insert({
              'receiver_id': mId,
              'sender_id': userId,
              'type': 'other',
              'content': 'Trưởng nhóm đã giải tán nhóm "$groupName". Bạn không thể truy cập vào nhóm này nữa',
            });
          }
        } catch (e) {
          debugPrint('⚠️ [ChatRepository] Lỗi gửi thông báo giải tán tới $mId: $e');
        }
      }
    }
  }

  /// Lấy danh sách thành viên và vai trò trong nhóm từ bảng `conversation_members`
  Future<List<ConversationMemberModel>> getConversationMembers(String conversationId) async {
    final data = await _client
        .from('conversation_members')
        .select('*, profile:profiles(*)')
        .eq('conversation_id', conversationId)
        .order('joined_at', ascending: true);

    return (data as List).map((e) => ConversationMemberModel.fromJson(e)).toList();
  }

  /// Cập nhật vai trò thành viên (owner, admin, member)
  Future<void> updateMemberRole(String conversationId, String targetUserId, String role) async {
    await _client
        .from('conversation_members')
        .update({'role': role})
        .eq('conversation_id', conversationId)
        .eq('user_id', targetUserId);
  }

  /// Xóa thành viên khỏi nhóm hoặc rời nhóm
  Future<void> removeGroupMember(String conversationId, String targetUserId) async {
    await _client
        .from('conversation_members')
        .delete()
        .eq('conversation_id', conversationId)
        .eq('user_id', targetUserId);
  }

  Future<int> getTotalUnreadMessagesCount() async {
    final userId = currentUserId!;
    final data = await _client
        .from('conversation_members')
        .select('unread_count')
        .eq('user_id', userId);

    int total = 0;
    for (var row in (data as List)) {
      total += (row['unread_count'] as int?) ?? 0;
    }
    return total;
  }

  Stream<int> watchTotalUnreadMessagesCount() async* {
    final userId = currentUserId;
    if (userId == null) {
      yield 0;
      return;
    }

    try {
      final initialCount = await getTotalUnreadMessagesCount();
      yield initialCount;
    } catch (e) {
      debugPrint('ℹ️ [watchTotalUnreadMessagesCount] Offline initial load: $e');
      yield 0;
    }

    final countStream = _client
        .from('conversation_members')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((data) {
          int total = 0;
          for (var row in data) {
            total += (row['unread_count'] as int?) ?? 0;
          }
          return total;
        })
        .handleError((err) {
          // Tự động kết nối lại khi WebSocket ngắt (không in log rác)
        });

    try {
      await for (final count in countStream) {
        yield count;
      }
    } catch (_) {}
  }

  // ── Conversation Actions ──────────────────────────────────────────────────────

  Future<void> togglePin(ConversationModel conv) async {
    final userId = currentUserId!;
    final currentlyPinned = conv.isPinnedState;

    await _client.from('conversation_members').update({
      'is_pinned': !currentlyPinned,
    }).eq('conversation_id', conv.id).eq('user_id', userId);
  }

  Future<void> toggleMute(String convId, bool currentMuteState) async {
    final userId = currentUserId!;
    await _client.from('conversation_members').update({
      'is_muted': !currentMuteState,
    }).eq('conversation_id', convId).eq('user_id', userId);
  }

  Future<void> toggleHide(ConversationModel conv) async {
    final userId = currentUserId!;
    final currentlyHidden = conv.isHiddenState;

    await _client.from('conversation_members').update({
      'is_hidden': !currentlyHidden,
    }).eq('conversation_id', conv.id).eq('user_id', userId);
  }

  Future<void> markAsRead(ConversationModel conv) async {
    await markAsSeen(conv.id);
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await _client.from(SupabaseConstants.messagesTable).delete().eq('conversation_id', conversationId);
    } catch (e, stack) {
      debugPrint('⚠️ [ChatRepository] Lỗi xóa tin nhắn: $e\n$stack');
    }

    try {
      await _client.from(SupabaseConstants.conversationsTable).delete().eq('id', conversationId);
    } catch (e, stack) {
      debugPrint('❌ [ChatRepository] Lỗi xóa cuộc trò chuyện: $e\n$stack');
      rethrow;
    }
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
    // 1. Nếu offset == 0, ưu tiên đọc hot cache từ Upstash Redis Cache trước (1-5ms)
    if (offset == 0 && _upstashRedis != null) {
      try {
        final cachedJsonList = await _upstashRedis!.getCachedRecentMessages(conversationId);
        if (cachedJsonList.isNotEmpty) {
          final cachedMsgs = cachedJsonList.map((e) => MessageModel.fromJson(e)).toList();
          debugPrint('⚡ [ChatRepository] 🚀 Hot hit Upstash Redis Cache: ${cachedMsgs.length} tin nhắn');
          return cachedMsgs;
        }
      } catch (e) {
        debugPrint('⚠️ [ChatRepository] Lỗi đọc Upstash Redis Cache: $e');
      }
    }

    try {
      // 2. Fetch từ Supabase Database
      final data = await _client
          .from(SupabaseConstants.messagesTable)
          .select('*, reply_to_message:reply_to_message_id(*), reactions:message_reactions(emoji, user_id)')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final msgs = (data as List).map((e) => MessageModel.fromJson(e)).toList();

      // 3. Sync messages to local DB (platform-independent)
      if (_isarService != null && msgs.isNotEmpty) {
        final jsonMsgs = msgs.map((m) => {
          'id': m.id,
          'conversation_id': m.conversationId,
          'sender_id': m.senderId,
          'content': m.content ?? '',
          'message_type': m.messageType,
          'created_at': m.createdAt.toIso8601String(),
          'reply_to_message_id': m.replyToMessageId,
          'status': 'sent',
          'media_urls': m.mediaUrls,
        }).toList();
        await _isarService!.saveMessages(conversationId, jsonMsgs);
        await _isarService!.pruneConversationMessages(conversationId, maxKeep: 100);
      }

      if (offset == 0 && _upstashRedis != null && data.isNotEmpty) {
        _upstashRedis!.cacheMessagesList(
          conversationId,
          List<Map<String, dynamic>>.from(data),
        ).catchError((err) {
          debugPrint('⚠️ [ChatRepository] Lỗi lưu Upstash Redis Cache: $err');
        });
      }

      return msgs;
    } catch (e) {
      debugPrint('⚠️ [ChatRepository] Offline fallback for messages: loading from local DB: $e');
      // Offline fallback: load from local DB
      if (_isarService != null) {
        final cached = _isarService!.getMessages(conversationId, limit: limit, offset: offset);
        return cached.map((m) {
          final rawMediaUrls = m['media_urls'];
          List<String> mediaUrls = const [];
          if (rawMediaUrls is List) {
            mediaUrls = rawMediaUrls.whereType<String>().toList();
          }
          return MessageModel(
            id: m['id'] as String,
            conversationId: m['conversation_id'] as String,
            senderId: m['sender_id'] as String,
            content: m['content'] as String?,
            messageType: m['message_type'] as String? ?? 'text',
            createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
            replyToMessageId: m['reply_to_message_id'] as String?,
            mediaUrls: mediaUrls,
          );
        }).toList();
      }
      rethrow;
    }
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
    final userId = currentUserId;
    if (userId != null && _upstashRedis != null) {
      final allowed = await _upstashRedis!.checkRateLimit(
        userId,
        maxRequests: 5,
        windowSeconds: 15,
      );
      if (!allowed) {
        throw Exception('Bạn đang gửi tin nhắn quá nhanh (tối đa 5 tin/15s). Vui lòng đợi trong giây lát!');
      }
    }

    final tempId = _uuid.v4();
    final now = DateTime.now().toUtc();

    // 1. Lưu tin nhắn optimistic vào local DB ngay lập tức
    await _isarService?.saveMessages(conversationId, [
      {
        'id': tempId,
        'conversation_id': conversationId,
        'sender_id': currentUserId ?? '',
        'content': content,
        'message_type': messageType,
        'created_at': now.toIso8601String(),
        'reply_to_message_id': replyToMessageId,
        'status': 'sending',
        'media_urls': <String>[],
      }
    ]);

    try {
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

      final realMsg = MessageModel.fromJson(data);

      await _client.from(SupabaseConstants.conversationsTable).update({
        'last_message': content,
        'last_message_at': now.toIso8601String(),
      }).eq('id', conversationId);

      // Cập nhật trạng thái 'sent' và ID chính thức trên local DB
      await _isarService?.saveMessages(conversationId, [
        {
          'id': realMsg.id,
          'conversation_id': realMsg.conversationId,
          'sender_id': realMsg.senderId,
          'content': realMsg.content ?? '',
          'message_type': realMsg.messageType,
          'created_at': realMsg.createdAt.toIso8601String(),
          'reply_to_message_id': realMsg.replyToMessageId,
          'status': 'sent',
          'media_urls': realMsg.mediaUrls,
        }
      ]);

      if (_upstashRedis != null) {
        _upstashRedis!.cacheRecentMessage(conversationId, data).catchError((err) {
          debugPrint('⚠️ [ChatRepository] Lỗi cache recent message lên Upstash Redis: $err');
        });
      }

      return realMsg;
    } catch (e, stack) {
      debugPrint('⚠️ [ChatRepository.sendMessage Error]: $e. Enqueueing to offline sync queue...');
      
      // Đẩy vào Outbox Sync Queue khi không có mạng
      if (_syncEngine != null) {
        await _syncEngine!.enqueueAction(
          actionType: 'sendMessage',
          payload: {
            'conversation_id': conversationId,
            'content': content,
            'message_type': messageType,
            if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
          },
        );
      }

      return MessageModel(
        id: tempId,
        conversationId: conversationId,
        senderId: currentUserId ?? '',
        content: content,
        messageType: messageType,
        createdAt: now,
        replyToMessageId: replyToMessageId,
      );
    }
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
    
    // Tự động nén ảnh tin nhắn chat
    final compressedBytes = await ImageCompressor.compressXFile(image);
    final contentType = ext == 'png'
        ? 'image/png'
        : (ext == 'gif' ? 'image/gif' : 'image/jpeg');

    await _client.storage
        .from(SupabaseConstants.messagesBucket)
        .uploadBinary(
          fileName,
          compressedBytes,
          fileOptions: FileOptions(
            contentType: contentType,
            cacheControl: '31536000', // 1 năm caching trên CDN
          ),
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
          'media_urls': [url],
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

    // Invalidate Redis cache so next load fetches fresh from Supabase (contains media_urls)
    if (_upstashRedis != null) {
      _upstashRedis!.invalidateMessagesCache(conversationId).catchError((err) {
        debugPrint('⚠️ [ChatRepository] Lỗi invalidate Redis cache (image): $err');
      });
    }

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
          'media_urls': [url],
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

    // Invalidate Redis cache so next load fetches fresh from Supabase (contains media_urls)
    if (_upstashRedis != null) {
      _upstashRedis!.invalidateMessagesCache(conversationId).catchError((err) {
        debugPrint('⚠️ [ChatRepository] Lỗi invalidate Redis cache (voice): $err');
      });
    }

    return MessageModel.fromJson(data);
  }

  Future<void> markAsSeen(String conversationId) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      // 1. Reset unread count for current user in conversation_members
      await _client.from('conversation_members').update({
        'unread_count': 0,
        'last_read_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('conversation_id', conversationId).eq('user_id', userId);
    } catch (_) {
      debugPrint('ℹ️ [ChatRepository.markAsSeen] Offline - skipped conversation_members update');
    }

    try {
      // 2. Mark messages from other senders as seen and update seen_at timestamp
      final nowUtcIso = DateTime.now().toUtc().toIso8601String();
      await _client
          .from(SupabaseConstants.messagesTable)
          .update({
            'is_seen': true,
            'seen_at': nowUtcIso,
          })
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .eq('is_seen', false);
    } catch (_) {
      debugPrint('ℹ️ [ChatRepository.markAsSeen] Offline - skipped messages update');
    }

    // 3. Invalidate Redis cache so next load fetches fresh is_seen: true from Supabase
    if (_upstashRedis != null) {
      _upstashRedis!.invalidateMessagesCache(conversationId).catchError((err) {
        debugPrint('⚠️ [ChatRepository.markAsSeen] Lỗi invalidate Redis cache: $err');
      });
    }
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
          'media_urls': [],
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

  // ── Hidden Conversations Passcode ──────────────────────────────────────────

  String hashPasscode(String passcode) {
    final userId = currentUserId ?? '';
    final bytes = utf8.encode('$passcode:$userId');
    return sha256.convert(bytes).toString();
  }

  Future<String?> getHiddenPasscode() async {
    final userId = currentUserId;
    if (userId == null) return null;
    try {
      final res = await _client
          .from('user_chat_passcodes')
          .select('passcode_hash')
          .eq('user_id', userId)
          .maybeSingle();
      if (res != null && res['passcode_hash'] != null) {
        return res['passcode_hash'] as String;
      }
    } catch (e) {
      debugPrint('ℹ️ [getHiddenPasscode] Error or table missing: $e');
    }
    return null;
  }

  Future<void> setHiddenPasscode(String rawPasscode) async {
    final userId = currentUserId;
    if (userId == null) return;
    final hashed = hashPasscode(rawPasscode);
    await _client.from('user_chat_passcodes').upsert({
      'user_id': userId,
      'passcode_hash': hashed,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<bool> verifyHiddenPasscode(String rawInput) async {
    final storedHash = await getHiddenPasscode();
    if (storedHash == null) return false;
    final inputHash = hashPasscode(rawInput);
    return storedHash == inputHash;
  }

  Future<void> removeHiddenPasscode() async {
    final userId = currentUserId;
    if (userId == null) return;
    try {
      await _client.from('user_chat_passcodes').delete().eq('user_id', userId);
    } catch (_) {}
  }
}
