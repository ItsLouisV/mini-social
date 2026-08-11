import 'package:flutter_test/flutter_test.dart';
import 'package:viora/features/call/domain/call_model.dart';

void main() {
  group('CallModel', () {
    test('parses hardened call fields and server duration', () {
      final call = CallModel.fromJson({
        'id': 'call-id',
        'conversation_id': 'conversation-id',
        'caller_id': 'caller-id',
        'callee_id': 'callee-id',
        'type': 'video',
        'status': 'ended',
        'room_name': 'room-id',
        'started_at': '2026-08-11T10:00:00Z',
        'connected_at': '2026-08-11T10:00:05Z',
        'media_connected_at': '2026-08-11T10:00:08Z',
        'ended_at': '2026-08-11T10:01:08Z',
        'expires_at': '2026-08-11T10:01:00Z',
        'duration_sec': 60,
        'answered_device_id': 'device_12345678',
        'end_reason': 'hangup',
      });

      expect(call.type, CallType.video);
      expect(call.status, CallStatus.ended);
      expect(call.durationSec, 60);
      expect(call.answeredDeviceId, 'device_12345678');
      expect(call.endReason, 'hangup');
      expect(call.mediaConnectedAt, isNotNull);
      expect(call.expiresAt, isNotNull);
    });

    test('computes current duration from connected timestamp', () {
      final call = CallModel.fromJson({
        'id': 'call-id',
        'conversation_id': 'conversation-id',
        'caller_id': 'caller-id',
        'callee_id': 'callee-id',
        'type': 'voice',
        'status': 'ended',
        'room_name': 'room-id',
        'started_at': '2026-08-11T10:00:00Z',
        'connected_at': '2026-08-11T10:00:05Z',
        'ended_at': '2026-08-11T10:00:35Z',
      });

      expect(call.currentDuration, const Duration(seconds: 30));
    });
  });
}
