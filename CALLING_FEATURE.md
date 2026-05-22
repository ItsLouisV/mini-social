# 📞 Tính năng Gọi điện / Video Call

> Tài liệu thiết kế và hướng dẫn triển khai tính năng gọi thoại và video cho MiniSocial.  
> Stack: **Flutter + Supabase + Agora RTC**

---

## Lựa chọn SDK

| SDK | Ưu điểm | Nhược điểm | Free tier |
|-----|---------|-----------|-----------|
| **Agora** ⭐ | SDK trưởng thành, Flutter support tốt, tự làm UI | Cần tự build UI, cần backend tạo token | 10.000 phút/tháng |
| Zego UIKit | UI call có sẵn, tích hợp ~30 phút | Ít linh hoạt về UI/UX | 10.000 phút/tháng |
| LiveKit | Open source, tự host được, miễn phí | Cần deploy server riêng | Miễn phí (self-host) |

> **Chọn Agora** vì tự làm UI — đồng bộ với dark mode và `AppColors` hiện có.

---

## 1. Database Schema

### Bảng `calls`

```sql
create type call_status as enum (
  'ringing',   -- đang đổ chuông
  'accepted',  -- đã chấp nhận, đang kết nối
  'declined',  -- bị từ chối
  'ended',     -- đã kết thúc
  'missed',    -- không nhấc máy (timeout)
  'cancelled'  -- người gọi tự huỷ trước khi được nhấc
);

create type call_type as enum ('voice', 'video');

create table calls (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid references conversations(id) on delete cascade not null,
  caller_id       uuid references profiles(id)      on delete cascade not null,
  callee_id       uuid references profiles(id)      on delete cascade not null,
  type            call_type   not null default 'voice',
  status          call_status not null default 'ringing',
  channel_id      text        not null,         -- ID phòng Agora (UUID duy nhất)
  started_at      timestamptz default now(),    -- lúc bắt đầu đổ chuông
  connected_at    timestamptz,                  -- lúc callee nhấc máy
  ended_at        timestamptz,                  -- lúc kết thúc cuộc gọi
  duration_sec    int                           -- thời lượng (giây), tính sau khi kết thúc
);

create index on calls (callee_id, status, started_at desc);
create index on calls (caller_id, started_at desc);
create index on calls (conversation_id, started_at desc);
```

### Row Level Security

```sql
alter table calls enable row level security;

create policy "Participants view calls" on calls
  for select using (auth.uid() = caller_id or auth.uid() = callee_id);

create policy "Users create calls" on calls
  for insert with check (auth.uid() = caller_id);

create policy "Participants update call status" on calls
  for update using (auth.uid() = caller_id or auth.uid() = callee_id);
```

### Realtime (để callee nhận sự kiện tức thời)

```sql
alter publication supabase_realtime add table calls;
```

---

## 2. Cấu trúc thư mục

```
lib/features/call/
├── data/
│   └── call_repository.dart          # CRUD + Agora token
├── domain/
│   └── call_model.dart               # Model cho bảng calls
├── presentation/
│   ├── screens/
│   │   ├── outgoing_call_screen.dart # Màn hình đang gọi đi (đổ chuông)
│   │   ├── incoming_call_screen.dart # Màn hình nhận cuộc gọi
│   │   └── active_call_screen.dart   # Màn hình đang trong cuộc gọi
│   └── widgets/
│       ├── call_button.dart          # Nút gọi thoại / video
│       └── call_control_bar.dart     # Thanh điều khiển (mute, camera, end)
└── providers/
    └── call_provider.dart            # Riverpod providers
```

---

## 3. Luồng hoạt động

### 3.1 Caller bắt đầu gọi

```
Caller bấm nút gọi
  │
  ├─ Tạo record trong bảng `calls` (status = 'ringing')
  ├─ Lấy Agora token từ backend (Edge Function hoặc server)
  ├─ Join channel Agora với channel_id
  └─ Mở OutgoingCallScreen (đang đổ chuông, countdown 60s)
        │
        ├─ Nếu Callee nhấc: status → 'accepted'  → chuyển sang ActiveCallScreen
        ├─ Nếu Callee từ chối: status → 'declined' → đóng màn hình
        ├─ Nếu timeout 60s: status → 'missed' → đóng màn hình
        └─ Nếu Caller huỷ: status → 'cancelled' → đóng màn hình
```

### 3.2 Callee nhận cuộc gọi

```
Supabase Realtime phát hiện INSERT vào bảng `calls` với callee_id = mình
  │
  └─ Hiện IncomingCallScreen (overlay toàn màn hình)
        │
        ├─ Nhấc máy: update status → 'accepted', update connected_at
        │               Lấy Agora token → Join channel → ActiveCallScreen
        └─ Từ chối: update status → 'declined' → đóng overlay
```

### 3.3 Kết thúc cuộc gọi

```
Một trong hai bấm kết thúc
  │
  ├─ Leave Agora channel
  ├─ Update calls: status → 'ended', ended_at, duration_sec
  └─ Quay về ChatScreen
```

---

## 4. Agora Token (Bảo mật)

> **Quan trọng:** Không hardcode App Certificate trên client. Tạo token trên server.

### Dùng Supabase Edge Function để tạo token

```typescript
// supabase/functions/agora-token/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { RtcTokenBuilder, RtcRole } from "npm:agora-token"

serve(async (req) => {
  const { channelId, uid } = await req.json()
  
  const appId = Deno.env.get('AGORA_APP_ID')!
  const appCertificate = Deno.env.get('AGORA_APP_CERTIFICATE')!
  
  const expirationTimeInSeconds = 3600 // 1 giờ
  const currentTimestamp = Math.floor(Date.now() / 1000)
  const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds

  const token = RtcTokenBuilder.buildTokenWithUid(
    appId,
    appCertificate,
    channelId,
    uid,
    RtcRole.PUBLISHER,
    expirationTimeInSeconds,
    privilegeExpiredTs,
  )

  return new Response(JSON.stringify({ token }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
```

---

## 5. pubspec.yaml

```yaml
dependencies:
  # Agora RTC
  agora_rtc_engine: ^6.3.2
  
  # Quyền camera/microphone
  permission_handler: ^11.3.1
```

---

## 6. Code mẫu

### 6.1 `call_model.dart`

```dart
enum CallStatus { ringing, accepted, declined, ended, missed, cancelled }
enum CallType   { voice, video }

class CallModel {
  final String id;
  final String conversationId;
  final String callerId;
  final String calleeId;
  final CallType type;
  final CallStatus status;
  final String channelId;
  final DateTime startedAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;
  final int? durationSec;

  const CallModel({ ... });

  factory CallModel.fromJson(Map<String, dynamic> json) => CallModel(
    id: json['id'],
    conversationId: json['conversation_id'],
    callerId: json['caller_id'],
    calleeId: json['callee_id'],
    type: json['type'] == 'video' ? CallType.video : CallType.voice,
    status: CallStatus.values.byName(json['status']),
    channelId: json['channel_id'],
    startedAt: DateTime.parse(json['started_at']).toLocal(),
    connectedAt: json['connected_at'] != null
        ? DateTime.parse(json['connected_at']).toLocal() : null,
    endedAt: json['ended_at'] != null
        ? DateTime.parse(json['ended_at']).toLocal() : null,
    durationSec: json['duration_sec'],
  );
}
```

### 6.2 `call_repository.dart`

```dart
class CallRepository {
  final SupabaseClient _client;
  CallRepository(this._client);

  // Tạo cuộc gọi mới
  Future<CallModel> createCall({
    required String conversationId,
    required String calleeId,
    required bool isVideo,
  }) async {
    final channelId = const Uuid().v4();
    final data = await _client.from('calls').insert({
      'conversation_id': conversationId,
      'caller_id': _client.auth.currentUser!.id,
      'callee_id': calleeId,
      'type': isVideo ? 'video' : 'voice',
      'channel_id': channelId,
      'status': 'ringing',
    }).select().single();
    return CallModel.fromJson(data);
  }

  // Cập nhật trạng thái
  Future<void> updateStatus(String callId, CallStatus status) async {
    final updates = <String, dynamic>{'status': status.name};
    if (status == CallStatus.accepted) {
      updates['connected_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (status == CallStatus.ended || status == CallStatus.declined) {
      final now = DateTime.now().toUtc();
      updates['ended_at'] = now.toIso8601String();
    }
    await _client.from('calls').update(updates).eq('id', callId);
  }

  // Lấy Agora token từ Edge Function
  Future<String> getAgoraToken(String channelId, int uid) async {
    final res = await _client.functions.invoke('agora-token', body: {
      'channelId': channelId,
      'uid': uid,
    });
    return res.data['token'] as String;
  }

  // Lắng nghe cuộc gọi đến (Realtime)
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
}
```

### 6.3 `active_call_screen.dart` — Agora RTC

```dart
class ActiveCallScreen extends ConsumerStatefulWidget {
  final CallModel call;
  const ActiveCallScreen({super.key, required this.call});

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen> {
  late final RtcEngine _engine;
  bool _muted = false;
  bool _cameraOff = false;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // 1. Xin quyền
    await [Permission.microphone, Permission.camera].request();

    // 2. Khởi tạo engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: dotenv.env['AGORA_APP_ID']!,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // 3. Lấy token & join channel
    final uid = ... // hash userId thành int
    final token = await ref.read(callRepositoryProvider)
        .getAgoraToken(widget.call.channelId, uid);

    await _engine.joinChannel(
      token: token,
      channelId: widget.call.channelId,
      uid: uid,
      options: const ChannelMediaOptions(),
    );
  }

  Future<void> _endCall() async {
    await _engine.leaveChannel();
    await _engine.release();
    
    final durationSec = widget.call.connectedAt != null
        ? DateTime.now().difference(widget.call.connectedAt!).inSeconds
        : 0;

    await ref.read(callRepositoryProvider).updateStatus(
      widget.call.id, CallStatus.ended,
    );
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (video call)
          if (widget.call.type == CallType.video)
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine,
                canvas: const VideoCanvas(uid: 0),
                connection: RtcConnection(channelId: widget.call.channelId),
              ),
            ),

          // Call controls
          Positioned(
            bottom: 60,
            left: 0, right: 0,
            child: _CallControlBar(
              muted: _muted,
              cameraOff: _cameraOff,
              isVideo: widget.call.type == CallType.video,
              onMute: () => setState(() {
                _muted = !_muted;
                _engine.muteLocalAudioStream(_muted);
              }),
              onCamera: () => setState(() {
                _cameraOff = !_cameraOff;
                _engine.muteLocalVideoStream(_cameraOff);
              }),
              onEnd: _endCall,
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 7. Android Permissions

Thêm vào `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

---

## 8. Environment Variables

Thêm vào `.env` và `.env.example`:

```env
# Agora
AGORA_APP_ID=your_agora_app_id
# AGORA_APP_CERTIFICATE chỉ dùng ở server (Edge Function), KHÔNG đưa vào client
```

Thêm vào Supabase Edge Function Secrets:
```
AGORA_APP_ID=...
AGORA_APP_CERTIFICATE=...
```

---

## 9. Lộ trình triển khai

- [ ] **Bước 1** — Tạo tài khoản Agora, lấy `App ID` + `App Certificate`
- [ ] **Bước 2** — Thêm bảng `calls` vào Supabase (SQL ở mục 1)
- [ ] **Bước 3** — Deploy Supabase Edge Function `agora-token`
- [ ] **Bước 4** — Thêm package `agora_rtc_engine`, `permission_handler`
- [ ] **Bước 5** — Tạo `CallModel`, `CallRepository`, `call_provider.dart`
- [ ] **Bước 6** — Xây dựng 3 màn hình: `OutgoingCallScreen`, `IncomingCallScreen`, `ActiveCallScreen`
- [ ] **Bước 7** — Tích hợp Realtime listener vào `App` root để nhận cuộc gọi đến mọi lúc
- [ ] **Bước 8** — Thêm nút gọi vào `ChatScreen` (đã có icon chờ)
- [ ] **Bước 9** — Test trên thiết bị vật lý (simulator không test được camera/mic)
- [ ] **Bước 10** — Thêm thông báo cuộc gọi nhỡ vào bảng `notifications`

---

## 10. Ghi chú quan trọng

> [!WARNING]
> Agora **không hỗ trợ tốt trên Flutter Web** do giới hạn WebRTC của trình duyệt. Nên ưu tiên test trên Android/iOS.

> [!NOTE]
> Cuộc gọi cần được lắng nghe ở **root widget** (không phải chỉ trong ChatScreen), để người dùng nhận được cuộc gọi ngay cả khi đang ở màn hình khác.

> [!TIP]
> Với **voice call**, không cần render `AgoraVideoView`. Chỉ cần quản lý audio engine — đơn giản hơn nhiều so với video.
