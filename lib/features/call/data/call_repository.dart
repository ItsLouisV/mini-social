import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/supabase_service.dart';

import '../domain/call_model.dart';

class CallRepository {
  final SupabaseService _service;
  CallRepository(this._service);

  SupabaseClient get _client => _service.client;

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

  /// Lắng nghe cuộc gọi đến bằng Realtime Channel (Postgres Changes)
  Stream<CallModel?> watchIncomingCall(String currentUserId) {
    final controller = StreamController<CallModel?>();

    // ✅ Subscribe channel TRƯỚC để không bỏ lỡ bất kỳ event nào trong lúc đang query
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

    // 2. Lắng nghe khi cuộc gọi bị cập nhật (UPDATE) — ví dụ: người gọi bấm Hủy
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
        if (data['status'] != 'ringing') {
          controller.add(null);
        }
      },
    );

    // ✅ Truyền callback vào subscribe để biết khi nào channel đã sẵn sàng
    // Sau đó mới query cuộc gọi đang chờ — tránh race condition
    try {
      channel.subscribe((status, [error]) async {
        if (status == RealtimeSubscribeStatus.channelError) {
          print('Supabase Realtime incoming calls channel error: $error');
          if (error != null) {
            await _service.handleAuthError(error);
          }
        }
        if (status != RealtimeSubscribeStatus.subscribed) return;

        try {
          final data = await _client
              .from('calls')
              .select()
              .eq('callee_id', currentUserId)
              .eq('status', 'ringing')
              .order('started_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (controller.isClosed) return;

          if (data == null) {
            controller.add(null);
            return;
          }

          final call = CallModel.fromJson(data);
          final isExpired =
              DateTime.now().difference(call.startedAt).inSeconds > 45;

          if (isExpired) {
            // Dọn dẹp cuộc gọi bị kẹt trạng thái từ phiên trước
            await updateStatus(call.id, CallStatus.missed);
            controller.add(null);
          } else {
            controller.add(call);
          }
        } catch (_) {
          if (!controller.isClosed) controller.add(null);
        }
      });
    } catch (e) {
      print('Error subscribing to incoming calls channel: $e');
    }

    // Hủy channel khi không còn lắng nghe stream để tránh rò rỉ bộ nhớ
    controller.onCancel = () {
      try {
        _client.removeChannel(channel);
      } catch (_) {}
      controller.close();
    };

    return controller.stream;
  }

  /// Lắng nghe thay đổi status của 1 cuộc gọi cụ thể bằng Realtime Channel
  Stream<CallModel> watchCall(String callId) {
    final controller = StreamController<CallModel>();
    final channel = _client.channel('call_state_$callId');

    try {
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
      ).subscribe((status, [error]) async {
        if (status == RealtimeSubscribeStatus.channelError) {
          print('Supabase Realtime watch call channel error: $error');
          if (error != null) {
            await _service.handleAuthError(error);
          }
        }
      });
    } catch (e) {
      print('Error subscribing to watch call channel: $e');
    }

    controller.onCancel = () {
      try {
        _client.removeChannel(channel);
      } catch (_) {}
      controller.close();
    };

    return controller.stream;
  }
}