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

  /// Lắng nghe cuộc gọi đến (Supabase Realtime)
  Stream<CallModel?> watchIncomingCall(String currentUserId) {
    return _client
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('callee_id', currentUserId)
        .map((list) {
      final ringing = list.where((c) => c['status'] == 'ringing').toList();
      return ringing.isEmpty ? null : CallModel.fromJson(ringing.first);
    });
  }

  /// Lắng nghe thay đổi status của 1 cuộc gọi cụ thể
  Stream<CallModel> watchCall(String callId) {
    return _client
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('id', callId)
        .map((list) => CallModel.fromJson(list.first));
  }
}
