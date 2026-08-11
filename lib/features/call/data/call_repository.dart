import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/supabase_service.dart';

import '../domain/call_model.dart';

class CallRepository {
  final SupabaseService _service;
  CallRepository(this._service);

  SupabaseClient get _client => _service.client;

  String getLiveKitUrl() => dotenv.env['LIVEKIT_URL'] ?? '';

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('call_device_id');
    if (id == null || id.length < 8) {
      id = 'device_${const Uuid().v4().replaceAll('-', '')}';
      await prefs.setString('call_device_id', id);
    }
    return id;
  }

  /// Tạo cuộc gọi mới trong bảng calls
  Future<CallModel> createCall({
    required String conversationId,
    required String calleeId,
    required bool isVideo,
  }) async {
    final callerId = _client.auth.currentUser?.id;
    if (callerId == null) throw StateError('Unauthenticated');
    if (callerId == calleeId) {
      throw ArgumentError('Bạn không thể tự gọi cho chính mình');
    }
    final data = await _client.rpc('start_call', params: {
      'p_conversation_id': conversationId,
      'p_callee_id': calleeId,
      'p_type': isVideo ? 'video' : 'voice',
    });
    return CallModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Cập nhật trạng thái cuộc gọi
  Future<CallModel> updateStatus(
    String callId,
    CallStatus status, {
    String? deviceId,
    String? reason,
  }) async {
    final data = await _client.rpc('transition_call', params: {
      'p_call_id': callId,
      'p_new_status': status.name,
      'p_device_id': deviceId,
      'p_reason': reason,
    });
    return CallModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<CallModel> markConnected(String callId) async {
    final data = await _client.rpc('mark_call_connected', params: {
      'p_call_id': callId,
    });
    return CallModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Lấy LiveKit token từ Edge Function
  Future<LiveKitCredentials> getLiveKitCredentials(String callId) async {
    final deviceId = await getDeviceId();
    final sessionId = 'session_${const Uuid().v4().replaceAll('-', '')}';
    final res = await _client.functions.invoke('livekit-token', body: {
      'callId': callId,
      'deviceId': deviceId,
      'clientSessionId': sessionId,
    });
    final data = Map<String, dynamic>.from(res.data as Map);
    return LiveKitCredentials(
      serverUrl: data['serverUrl'] as String,
      participantToken: data['participantToken'] as String,
    );
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
        if (data['status'] == 'ringing' && data['caller_id'] != currentUserId) {
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
          debugPrint('Supabase Realtime incoming calls channel error: $error');
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
              .neq('caller_id', currentUserId)
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
          final isExpired = call.expiresAt?.isBefore(DateTime.now()) ??
              DateTime.now().difference(call.startedAt).inSeconds > 60;

          if (isExpired) {
            // Dọn dẹp cuộc gọi bị kẹt trạng thái từ phiên trước
            await updateStatus(call.id, CallStatus.missed,
                reason: 'stale_ringing');
            controller.add(null);
          } else {
            controller.add(call);
          }
        } catch (_) {
          if (!controller.isClosed) controller.add(null);
        }
      });
    } catch (e) {
      debugPrint('Error subscribing to incoming calls channel: $e');
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
      channel
          .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'calls',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: callId,
        ),
        callback: (payload) {
          if (!controller.isClosed) {
            controller.add(CallModel.fromJson(payload.newRecord));
          }
        },
      )
          .subscribe((status, [error]) async {
        if (status == RealtimeSubscribeStatus.channelError) {
          debugPrint('Supabase Realtime watch call channel error: $error');
          if (error != null) {
            await _service.handleAuthError(error);
          }
        }
        if (status == RealtimeSubscribeStatus.subscribed) {
          try {
            final data =
                await _client.from('calls').select().eq('id', callId).single();
            if (!controller.isClosed) controller.add(CallModel.fromJson(data));
          } catch (e, stack) {
            if (!controller.isClosed) controller.addError(e, stack);
          }
        }
      });
    } catch (e) {
      debugPrint('Error subscribing to watch call channel: $e');
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

class LiveKitCredentials {
  final String serverUrl;
  final String participantToken;

  const LiveKitCredentials({
    required this.serverUrl,
    required this.participantToken,
  });
}
