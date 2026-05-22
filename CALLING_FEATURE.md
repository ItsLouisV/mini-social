# 📞 Tính năng Gọi điện / Video Call

> Tài liệu thiết kế và hướng dẫn triển khai tính năng gọi thoại và video cho MiniSocial.  
> Stack: **Flutter + Supabase + LiveKit**

---

## Lựa chọn SDK

| SDK | Android | Flutter Web | Free tier | Ghi chú |
|-----|---------|-------------|-----------|---------|
| **LiveKit** ⭐ | ✅ Tốt | ✅ Tốt nhất | ✅ LiveKit Cloud có free tier | WebRTC chuẩn → browser native |
| Agora | ✅ Tốt | ⚠️ Hạn chế | 10.000 phút/tháng | Flutter SDK chủ yếu cho mobile |
| Zego UIKit | ✅ Tốt | ✅ Có | 10.000 phút/tháng | UI prebuilt, khó custom |
| 100ms | ✅ Tốt | ✅ Có | 10.000 phút/tháng | Ít phổ biến hơn |

> **Chọn LiveKit** vì:
> - App đang chạy **đồng thời trên Web (Chrome) và Android vật lý**
> - Dựa trên **WebRTC chuẩn** → trình duyệt hỗ trợ native, không cần plugin
> - Package `livekit_client` hỗ trợ cả Flutter Web lẫn Android trong cùng 1 codebase
> - Có **LiveKit Cloud** dùng free, không cần tự host server

---

## 1. Database Schema

### Bảng `calls`

```sql
create type call_status as enum (
  'ringing',   -- đang đổ chuông
  'accepted',  -- đã chấp nhận, đang kết nối
  'declined',  -- bị từ chối
  'ended',     -- đã kết thúc
  'missed',    -- không nhấc máy (timeout 60s)
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
  room_name       text        not null,         -- Tên phòng LiveKit (UUID duy nhất)
  started_at      timestamptz default now(),    -- lúc bắt đầu đổ chuông
  connected_at    timestamptz,                  -- lúc callee nhấc máy
  ended_at        timestamptz,                  -- lúc kết thúc cuộc gọi
  duration_sec    int                           -- thời lượng (giây)
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
│   ├── call_repository.dart          # CRUD + lấy LiveKit token
│   └── call_audio_service.dart       # Quản lý âm thanh (ringtone, dial tone)
├── domain/
│   └── call_model.dart               # Model cho bảng calls
├── presentation/
│   ├── screens/
│   │   └── call_screens.dart         # Chứa Outgoing, Incoming, Active Call Screen
│   └── widgets/
│       └── call_control_bar.dart     # Thanh điều khiển (mute, camera, end)
└── providers/
    └── call_provider.dart            # Riverpod providers cho luồng cuộc gọi
```

---

## 3. Luồng hoạt động

### 3.1 Caller bắt đầu gọi

```
Caller bấm nút gọi
  │
  ├─ Tạo record trong bảng `calls` (status = 'ringing', room_name = UUID)
  ├─ Gọi Edge Function → lấy LiveKit token cho caller
  ├─ Connect vào LiveKit room
  └─ Mở OutgoingCallScreen (đang đổ chuông, countdown 60s)
        │
        ├─ Callee nhấc máy → status = 'accepted'  → ActiveCallScreen
        ├─ Callee từ chối  → status = 'declined'  → đóng màn hình
        ├─ Timeout 60s     → status = 'missed'    → đóng màn hình
        └─ Caller huỷ     → status = 'cancelled'  → đóng màn hình
```

### 3.2 Callee nhận cuộc gọi

```
Supabase Realtime: INSERT vào `calls` với callee_id = mình, status = 'ringing'
  │
  └─ Hiện IncomingCallScreen (overlay toàn màn hình)
        │
        ├─ Nhấc máy: update status → 'accepted', connected_at = now()
        │            Lấy LiveKit token → Connect room → ActiveCallScreen
        └─ Từ chối:  update status → 'declined' → đóng overlay
```

### 3.3 Kết thúc cuộc gọi

```
Một trong hai bấm kết thúc
  │
  ├─ Disconnect LiveKit room
  ├─ Update calls: status = 'ended', ended_at = now(), duration_sec = X
  └─ Quay về ChatScreen
```

---

## 4. LiveKit Token — Supabase Edge Function

> **Quan trọng:** API Secret chỉ dùng ở server. Không đưa vào client.

### Đăng ký LiveKit Cloud

1. Vào [livekit.io](https://livekit.io) → Tạo project
2. Lấy `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`

### Edge Function tạo token

```typescript
// supabase/functions/livekit-token/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { AccessToken } from "npm:livekit-server-sdk"

serve(async (req) => {
  const { roomName, participantIdentity, participantName } = await req.json()

  const apiKey    = Deno.env.get('LIVEKIT_API_KEY')!
  const apiSecret = Deno.env.get('LIVEKIT_API_SECRET')!

  const at = new AccessToken(apiKey, apiSecret, {
    identity: participantIdentity,
    name:     participantName,
    ttl:      '1h',
  })

  at.addGrant({
    roomJoin:     true,
    room:         roomName,
    canPublish:   true,
    canSubscribe: true,
  })

  const token = await at.toJwt()

  return new Response(JSON.stringify({ token }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
```

### Secrets cần set trên Supabase Dashboard

```
LIVEKIT_API_KEY=...
LIVEKIT_API_SECRET=...
```

---

## 5. pubspec.yaml

```yaml
dependencies:
  # LiveKit — hỗ trợ cả Flutter Web + Android + iOS
  livekit_client: ^2.3.0

  # Xin quyền camera/microphone (chỉ cần cho mobile)
  permission_handler: ^11.3.1
```

---

## 6. Environment Variables

Thêm vào `.env`:

```env
# LiveKit
LIVEKIT_URL=wss://your-project.livekit.cloud
# API Key/Secret chỉ dùng ở Edge Function, KHÔNG đưa vào .env client
```

---

## 7. Code mẫu

### 7.1 `call_model.dart`

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
  final String roomName;
  final DateTime startedAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;
  final int? durationSec;

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
  });

  factory CallModel.fromJson(Map<String, dynamic> json) => CallModel(
    id:             json['id'],
    conversationId: json['conversation_id'],
    callerId:       json['caller_id'],
    calleeId:       json['callee_id'],
    type:           json['type'] == 'video' ? CallType.video : CallType.voice,
    status:         CallStatus.values.byName(json['status']),
    roomName:       json['room_name'],
    startedAt:      DateTime.parse(json['started_at']).toLocal(),
    connectedAt:    json['connected_at'] != null
        ? DateTime.parse(json['connected_at']).toLocal() : null,
    endedAt:        json['ended_at'] != null
        ? DateTime.parse(json['ended_at']).toLocal() : null,
    durationSec:    json['duration_sec'],
  );
}
```

### 7.2 `call_repository.dart`

```dart
class CallRepository {
  final SupabaseClient _client;
  CallRepository(this._client);

  String get _livekitUrl => dotenv.env['LIVEKIT_URL']!;

  // Tạo cuộc gọi mới
  Future<CallModel> createCall({
    required String conversationId,
    required String calleeId,
    required bool isVideo,
  }) async {
    final roomName = const Uuid().v4();
    final data = await _client.from('calls').insert({
      'conversation_id': conversationId,
      'caller_id':       _client.auth.currentUser!.id,
      'callee_id':       calleeId,
      'type':            isVideo ? 'video' : 'voice',
      'room_name':       roomName,
      'status':          'ringing',
    }).select().single();
    return CallModel.fromJson(data);
  }

  // Cập nhật trạng thái
  Future<void> updateStatus(String callId, CallStatus status) async {
    final updates = <String, dynamic>{'status': status.name};
    if (status == CallStatus.accepted) {
      updates['connected_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (status == CallStatus.ended || status == CallStatus.declined ||
        status == CallStatus.missed || status == CallStatus.cancelled) {
      updates['ended_at'] = DateTime.now().toUtc().toIso8601String();
    }
    await _client.from('calls').update(updates).eq('id', callId);
  }

  // Lấy LiveKit token từ Edge Function
  Future<String> getLiveKitToken(String roomName) async {
    final user = _client.auth.currentUser!;
    final res = await _client.functions.invoke('livekit-token', body: {
      'roomName':            roomName,
      'participantIdentity': user.id,
      'participantName':     user.userMetadata['full_name'] ?? user.email,
    });
    return res.data['token'] as String;
  }

  // Lắng nghe cuộc gọi đến (Supabase Realtime)
  Stream<CallModel?> watchIncomingCall(String currentUserId) {
    return _client
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('callee_id', currentUserId)
        .map((list) {
          final ringing = list
              .where((c) => c['status'] == 'ringing')
              .toList();
          return ringing.isEmpty ? null : CallModel.fromJson(ringing.first);
        });
  }

  // Lắng nghe thay đổi status của 1 cuộc gọi cụ thể (để caller biết callee đã nhấc chưa)
  Stream<CallModel> watchCall(String callId) {
    return _client
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('id', callId)
        .map((list) => CallModel.fromJson(list.first));
  }
}
```

### 7.3 `active_call_screen.dart` — LiveKit

```dart
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActiveCallScreen extends ConsumerStatefulWidget {
  final CallModel call;
  const ActiveCallScreen({super.key, required this.call});

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen> {
  Room? _room;
  LocalParticipant? _localParticipant;
  bool _muted    = false;
  bool _cameraOff = false;

  @override
  void initState() {
    super.initState();
    _connectToRoom();
  }

  Future<void> _connectToRoom() async {
    // 1. Lấy token từ Edge Function
    final token = await ref
        .read(callRepositoryProvider)
        .getLiveKitToken(widget.call.roomName);

    // 2. Tạo và connect room
    final room = Room();
    await room.connect(
      dotenv.env['LIVEKIT_URL']!,
      token,
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );

    // 3. Bật camera/mic nếu có quyền
    await room.localParticipant?.setMicrophoneEnabled(true);
    if (widget.call.type == CallType.video) {
      await room.localParticipant?.setCameraEnabled(true);
    }

    if (mounted) {
      setState(() {
        _room = room;
        _localParticipant = room.localParticipant;
      });
    }
  }

  Future<void> _endCall() async {
    await _room?.disconnect();

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
    _room?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remoteParticipants = _room?.remoteParticipants.values.toList() ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video của người kia (nếu là video call)
          if (widget.call.type == CallType.video && remoteParticipants.isNotEmpty)
            _RemoteVideoView(participant: remoteParticipants.first),

          // Video local (góc nhỏ)
          if (widget.call.type == CallType.video && _localParticipant != null)
            Positioned(
              top: 60, right: 16,
              child: SizedBox(
                width: 100, height: 140,
                child: _LocalVideoView(participant: _localParticipant!),
              ),
            ),

          // Thanh điều khiển
          Positioned(
            bottom: 60, left: 0, right: 0,
            child: _CallControlBar(
              muted:    _muted,
              cameraOff: _cameraOff,
              isVideo:  widget.call.type == CallType.video,
              onMute: () async {
                await _localParticipant?.setMicrophoneEnabled(_muted);
                setState(() => _muted = !_muted);
              },
              onCamera: () async {
                await _localParticipant?.setCameraEnabled(_cameraOff);
                setState(() => _cameraOff = !_cameraOff);
              },
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

## 8. Android & Web — Xử lý nền tảng

### Android Permissions

Thêm vào `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

### Flutter Web

> LiveKit dùng WebRTC chuẩn nên **không cần cấu hình thêm** cho Web.  
> Trình duyệt tự hỏi quyền camera/microphone khi user join phòng.

> [!NOTE]
> Trên Web, **không dùng `permission_handler`** vì package đó không hỗ trợ Web.
> Dùng `kIsWeb` để skip phần xin quyền trên web:
> ```dart
> if (!kIsWeb) {
>   await [Permission.microphone, Permission.camera].request();
> }
> ```

---

## 9. Lộ trình triển khai

- [x] **Bước 1** — Tạo tài khoản [LiveKit Cloud](https://livekit.io), lấy URL + API Key + Secret
- [x] **Bước 2** — Thêm bảng `calls` vào Supabase (SQL ở mục 1)
- [x] **Bước 3** — Deploy Supabase Edge Function `livekit-token` + set secrets
- [x] **Bước 4** — Thêm `LIVEKIT_URL` vào `.env`, thêm package `livekit_client`, `permission_handler`, `audioplayers`
- [x] **Bước 5** — Tạo `CallModel`, `CallRepository`, `call_provider.dart`, `call_audio_service.dart`
- [x] **Bước 6** — Xây dựng màn hình trong `call_screens.dart`: `OutgoingCallScreen`, `IncomingCallScreen`, `ActiveCallScreen`
- [x] **Bước 7** — Tích hợp Realtime listener vào `call_provider.dart` và route tại `app_router.dart` để nhận cuộc gọi mọi lúc
- [x] **Bước 8** — Bật nút gọi thoại / video trong `ChatScreen`
- [x] **Bước 9** — Test: Web ↔ Android cùng join 1 room, tinh chỉnh giao diện (đồng hồ, hình nền, avatar)
- [x] **Bước 10** — Thêm ghi chú cuộc gọi vào màn hình tin nhắn khi cuộc gọi kết thúc/nhỡ

---

## 10. Ghi chú quan trọng

> [!IMPORTANT]
> LiveKit Cloud có **free tier 10.000 phút/tháng**. Đủ để test và demo nhóm nhỏ.

> [!NOTE]
> Cuộc gọi đến phải được lắng nghe ở **root widget** — không phải chỉ trong ChatScreen —  
> để người dùng nhận được cuộc gọi dù đang ở bất kỳ màn hình nào.

> [!TIP]
> Với **voice call**, disable camera track là đủ. Không cần render `VideoView` nào,  
> chỉ cần quản lý audio track → UI call đơn giản hơn nhiều so với video.

> [!WARNING]
> Tránh dùng `permission_handler` trên Web — sẽ compile error.  
> Dùng `kIsWeb` để phân nhánh xử lý nền tảng.
