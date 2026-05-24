import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/call_model.dart';

class CallRepository {
  final SupabaseClient _client;
  CallRepository(this._client);

  String getLiveKitUrl() => dotenv.env['LIVEKIT_URL'] ?? '';

  /// Tạo cuộc gọi mới trong bảng calls
  Future<CallModel> createCall({
    required String conversationId,
    required String calleeId,
    required bool isVideo,
  }) async {
    final roomName = const Uuid().v4();
    final data = await _client.from('calls').insert({
      'conversation_id': conversationId,
      'caller_id': _client.auth.currentUser!.id,
      'callee_id': calleeId,
      'type': isVideo ? 'video' : 'voice',
      'room_name': roomName,
      'status': 'ringing',
    }).select().single();
    return CallModel.fromJson(data);
  }

  /// Cập nhật trạng thái cuộc gọi
  Future<void> updateStatus(String callId, CallStatus status) async {
    final updates = <String, dynamic>{'status': status.name};
    
    if (status == CallStatus.accepted) {
      updates['connected_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (status == CallStatus.ended ||
        status == CallStatus.declined ||
        status == CallStatus.missed ||
        status == CallStatus.cancelled) {
      updates['ended_at'] = DateTime.now().toUtc().toIso8601String();
    }

    await _client.from('calls').update(updates).eq('id', callId);
  }

  /// Lấy LiveKit token từ Edge Function
  Future<String> getLiveKitToken(String roomName) async {
    final user = _client.auth.currentUser!;
    final res = await _client.functions.invoke('livekit-token', body: {
      'roomName': roomName,
      'participantIdentity': user.id,
      'participantName': user.userMetadata?['full_name'] ?? user.email ?? 'Unknown',
    });
    return res.data['token'] as String;
  }

  /// [ĐÃ SỬA LỖI] Lắng nghe cuộc gọi đến bằng Realtime Channel (Postgres Changes)
  Stream<CallModel?> watchIncomingCall(String currentUserId) {
    final controller = StreamController<CallModel?>();
    
    // Khởi tạo một channel độc lập cho user
    final channel = _client.channel('incoming_calls_$currentUserId');

    // 1. Lắng nghe khi có cuộc gọi mới tạo (INSERT) cho mình
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'calls',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'callee_id',
        value: currentUserId,
      ),
      callback: (payload) {
        final data = payload.newRecord;
        if (data['status'] == 'ringing') {
          controller.add(CallModel.fromJson(data));
        }
      },
    );

    // 2. Lắng nghe khi cuộc gọi đó bị cập nhật trạng thái (UPDATE) - ví dụ: người gọi bấm Hủy
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'calls',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'callee_id',
        value: currentUserId,
      ),
      callback: (payload) {
        final data = payload.newRecord;
        // Nếu cuộc gọi không còn ở trạng thái ringing nữa, bắn null để tắt màn hình đổ chuông
        if (data['status'] != 'ringing') {
          controller.add(null);
        }
      },
    );

    channel.subscribe();

    // Hủy channel khi widget không còn lắng nghe stream này nữa để tránh rò rỉ bộ nhớ
    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  /// [ĐÃ SỬA LỖI] Lắng nghe thay đổi status của 1 cuộc gọi cụ thể bằng Realtime Channel
  Stream<CallModel> watchCall(String callId) {
    final controller = StreamController<CallModel>();
    final channel = _client.channel('call_state_$callId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'calls',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: callId,
      ),
      callback: (payload) {
        controller.add(CallModel.fromJson(payload.newRecord));
      },
    ).subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }
}

