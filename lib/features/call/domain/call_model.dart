enum CallStatus { ringing, accepted, declined, ended, missed, cancelled }

enum CallType { voice, video }

class CallModel {
  final String id;
  final String conversationId;
  final String callerId;
  final String calleeId;
  final CallType type;
  final CallStatus status;
  final String roomName;
  final DateTime startedAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;
  final int? durationSec;
  final DateTime? expiresAt;
  final String? answeredDeviceId;
  final String? endReason;
  final DateTime? mediaConnectedAt;

  const CallModel({
    required this.id,
    required this.conversationId,
    required this.callerId,
    required this.calleeId,
    required this.type,
    required this.status,
    required this.roomName,
    required this.startedAt,
    this.connectedAt,
    this.endedAt,
    this.durationSec,
    this.expiresAt,
    this.answeredDeviceId,
    this.endReason,
    this.mediaConnectedAt,
  });

  factory CallModel.fromJson(Map<String, dynamic> json) => CallModel(
        id: json['id'] as String,
        conversationId: json['conversation_id'] as String,
        callerId: json['caller_id'] as String,
        calleeId: json['callee_id'] as String,
        type: json['type'] == 'video' ? CallType.video : CallType.voice,
        status: CallStatus.values.byName(json['status'] as String),
        roomName: json['room_name'] as String,
        startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
        connectedAt: json['connected_at'] != null
            ? DateTime.parse(json['connected_at'] as String).toLocal()
            : null,
        endedAt: json['ended_at'] != null
            ? DateTime.parse(json['ended_at'] as String).toLocal()
            : null,
        durationSec: json['duration_sec'] as int?,
        expiresAt: json['expires_at'] != null
            ? DateTime.parse(json['expires_at'] as String).toLocal()
            : null,
        answeredDeviceId: json['answered_device_id'] as String?,
        endReason: json['end_reason'] as String?,
        mediaConnectedAt: json['media_connected_at'] != null
            ? DateTime.parse(json['media_connected_at'] as String).toLocal()
            : null,
      );

  bool get isVideo => type == CallType.video;

  /// Thời lượng cuộc gọi (nếu đang trong call)
  Duration? get currentDuration {
    if (connectedAt == null) return null;
    final end = endedAt ?? DateTime.now();
    return end.difference(connectedAt!);
  }
}
