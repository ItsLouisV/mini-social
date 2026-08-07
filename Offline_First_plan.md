# Kế hoạch Tái cấu trúc Kiến trúc Offline-First (Isar DB & Supabase)

Tài liệu này chi tiết hóa kế hoạch nâng cấp ứng dụng Flutter sang kiến trúc **Offline-First**, đáp ứng khả năng hoạt động mượt mà khi mất mạng và đồng bộ dữ liệu tức thì khi có lại kết nối mạng trên cả **Mobile (Android/iOS)** và **Web (IndexedDB)**.

---

## 🎯 Mục tiêu Kiến trúc

```
                  Supabase (Cloud Backend)
        ┌────────────────────────────────────────┐
        │ - PostgreSQL                           │
        │ - Storage (Media CDN)                  │
        │ - Realtime Subscriptions               │
        └───────────────────┬────────────────────┘
                            │
                    Repository Layer
              (Single Source of Truth cho UI)
                            │
      ┌─────────────────────┴─────────────────────┐
      ▼                                           ▼
  Isar Database                              Flutter UI
(Mobile DB / Web IndexedDB)               (Reactive Streams)
```

1. **Single Source of Truth**: UI chỉ đọc dữ liệu từ **Isar Database** (qua Reactive Streams). UI không cần quan tâm dữ liệu tới từ Server hay Cache.
2. **Offline Writing & Outbox Pattern**: Khi thao tác trong lúc offline (gửi tin nhắn, tạo bài viết, like, comment...), dữ liệu lập tức ghi vào Isar + lưu vào `IsarSyncQueue`. Khi có mạng lại, `SyncEngine` tự động đẩy lên Supabase theo thứ tự.
3. **Delta Sync & Timestamping**: Đồng bộ dữ liệu bằng so sánh `updated_at` để chỉ tải dữ liệu mới/thay đổi từ Supabase về Isar, tiết kiệm băng thông.
4. **Tối ưu Media Caching**:
   - Isar chỉ lưu URL & Metadata (`messageId`, `imageUrl`, `width`, `height`, `duration`, `waveform`). KHÔNG lưu file nhị phân trong DB.
   - **Mobile**: Sử dụng `flutter_cache_manager` cache file ảnh/video/voice vào đĩa cục bộ khi người dùng xem/phát.
   - **Web**: Dựa trên HTTP Cache-Control & Browser Cache API.

---

## ⚠️ User Review Required

> [!IMPORTANT]
> **1. Thay thế ObjectBox bằng Isar DB:**
> ObjectBox bị hạn chế lớn trên Web (cần Wasm/Emscripten phức tạp). Việc chuyển sang **Isar DB** sẽ loại bỏ hoàn toàn mã nguồn ObjectBox (`objectbox.g.dart`, `objectbox-model.json`, `objectbox_service*.dart`) và thay bằng **Isar 3.x / 4.x** hoạt động natively trên cả Mobile & Web (IndexedDB).
>
> **2. Migrations trên Supabase:**
> Các bảng trên Supabase (như `messages`, `posts`, `profiles`, `conversations`, `notifications`) cần đảm bảo có cột `updated_at` (timestamptz) và cờ `is_deleted` (boolean, hỗ trợ soft delete) để đồng bộ delta sync chính xác.

---

## 📊 Bảng Phạm vi Cache (Cache Matrix)

| Thành phần | Mobile (Android/iOS) | Web (Chrome/Edge/Safari) | Ghi chú kỹ thuật |
| :--- | :--- | :--- | :--- |
| **Database Local** | **Isar (Native)** | **Isar (IndexedDB)** | Đồng bộ qua `IsarService` |
| **Tin nhắn (Messages)** | ✅ Cache Isar | ✅ Cache Isar | Giới hạn 50-100 tin nhắn mới nhất / conversation |
| **Danh sách chat** | ✅ Cache Isar | ✅ Cache Isar | `IsarConversation` collection |
| **Feed (Bài viết)** | ✅ Cache Isar | ✅ Cache Isar | `IsarPost` collection |
| **Hồ sơ (Profile)** | ✅ Cache Isar | ✅ Cache Isar | `IsarProfile` collection |
| **Cài đặt (Settings)** | ✅ Cache Isar | ✅ Cache Isar | `IsarSettings` key-value collection |
| **Thông báo** | ✅ Cache Isar | ✅ Cache Isar | `IsarNotification` collection |
| **Lịch sử tìm kiếm** | ✅ Cache Isar | ✅ Cache Isar | `IsarSearchHistory` collection |
| **Bản nháp bài viết** | ✅ Cache Isar | ✅ Cache Isar | `IsarPostDraft` collection |
| **Ảnh (Image)** | Cache file local | Cache trình duyệt | Storage URL + `flutter_cache_manager` / Browser HTTP cache |
| **Video** | Cache khi xem | Cache trình duyệt | Tải stream/chunk khi người dùng nhấn phát |
| **Voice** | Cache khi phát | Cache trình duyệt | Lưu cache audio file theo URL |
| **File lớn / Data khủng** | ❌ Không lưu toàn bộ | ❌ Không lưu toàn bộ | Giới hạn retention period & max cache limit |

---

## Proposed Changes

### 1. Quản lý Phụ thuộc (`pubspec.yaml`)

#### [MODIFY] [pubspec.yaml](file:///c:/cross_platform/mini_social/pubspec.yaml)
- **Thêm**: `isar: ^3.1.0+1`, `isar_flutter_libs: ^3.1.0+1`, `flutter_cache_manager: ^3.3.2`
- **Thêm dev_dependencies**: `isar_generator: ^3.1.0+1`
- **Xóa**: `objectbox`, `objectbox_flutter_libs`, `objectbox_generator`

---

### 2. Core Infrastructure & Services

#### [NEW] [isar_service.dart](file:///c:/cross_platform/mini_social/lib/core/services/isar_service.dart)
- Khởi tạo singleton Isar DatabaseInstance cho cả Mobile (dùng `getApplicationDocumentsDirectory()`) và Web (IndexedDB).
- Đăng ký tất cả Isar Collections (`IsarMessageSchema`, `IsarConversationSchema`, `IsarPostSchema`, `IsarProfileSchema`, `IsarNotificationSchema`, `IsarSettingsSchema`, `IsarSearchHistorySchema`, `IsarPostDraftSchema`, `IsarSyncQueueSchema`).

#### [NEW] [sync_engine.dart](file:///c:/cross_platform/mini_social/lib/core/services/sync_engine.dart)
- Quản lý đồng bộ 2 chiều tussen Supabase và Isar:
  - **Pull (Delta Sync)**: Lấy `last_synced_at` từ `IsarSettings`, query Supabase `gte('updated_at', lastSyncedAt)`, lưu/cập nhật vào Isar trong `isar.writeTxn()`.
  - **Push (Outbox Queue)**: Đọc các item từ `IsarSyncQueue` khi có mạng, thực thi các mutation API Supabase, cập nhật ID thực sự và xoá queue item.
  - Lắng nghe trạng thái mạng từ `ConnectivityService`.

#### [NEW] [media_cache_manager.dart](file:///c:/cross_platform/mini_social/lib/core/services/media_cache_manager.dart)
- Quản lý cache media trên Mobile (`DefaultCacheManager` tùy chỉnh) và Web (HTTP Cache headers):
  - Tải trước / Lấy file local cho ảnh, video, voice.
  - Tự động dọn dẹp file media cũ khi dung lượng đĩa vượt ngưỡng (ví dụ > 500MB).

#### [DELETE] [objectbox_service.dart](file:///c:/cross_platform/mini_social/lib/core/services/objectbox_service.dart)
#### [DELETE] [objectbox_service_native.dart](file:///c:/cross_platform/mini_social/lib/core/services/objectbox_service_native.dart)
#### [DELETE] [objectbox_service_stub.dart](file:///c:/cross_platform/mini_social/lib/core/services/objectbox_service_stub.dart)
#### [DELETE] [objectbox.g.dart](file:///c:/cross_platform/mini_social/lib/objectbox.g.dart)
#### [DELETE] [objectbox-model.json](file:///c:/cross_platform/mini_social/lib/objectbox-model.json)

---

### 3. Isar Collections (Local Schemas)

#### [NEW] [isar_message.dart](file:///c:/cross_platform/mini_social/lib/core/database/collections/isar_message.dart)
- `@collection` cho tin nhắn chat: `id` (String / FastHash Id), `conversationId` (Index), `senderId`, `content`, `messageType`, `createdAt`, `replyToId`, `status` (sending, sent, error), metadata (`width`, `height`, `duration`, `waveform`).

#### [NEW] [isar_conversation.dart](file:///c:/cross_platform/mini_social/lib/core/database/collections/isar_conversation.dart)
- `@collection` cho danh sách hội thoại: `id` (Index), `type` (direct/group), `name`, `avatarUrl`, `lastMessage`, `lastMessageAt`, `unreadCount`, `isPinned`, `isMuted`, `isHidden`, `updatedAt`.

#### [NEW] [isar_post.dart](file:///c:/cross_platform/mini_social/lib/core/database/collections/isar_post.dart)
- `@collection` cho Feed bài viết: `id`, `authorId`, `authorName`, `authorAvatar`, `content`, `imageUrls` (List<String>), `videoUrl`, `likesCount`, `commentsCount`, `isLiked`, `createdAt`, `updatedAt`.

#### [NEW] [isar_profile.dart](file:///c:/cross_platform/mini_social/lib/core/database/collections/isar_profile.dart)
- `@collection` cho hồ sơ người dùng: `id`, `username`, `fullName`, `avatarUrl`, `bio`, `followerCount`, `followingCount`, `updatedAt`.

#### [NEW] [isar_notification.dart](file:///c:/cross_platform/mini_social/lib/core/database/collections/isar_notification.dart)
- `@collection` cho thông báo: `id`, `receiverId`, `senderId`, `type`, `content`, `isRead`, `createdAt`.

#### [NEW] [isar_settings.dart](file:///c:/cross_platform/mini_social/lib/core/database/collections/isar_settings.dart)
- `@collection` cho Cài đặt & Trạng thái Sync: `key` (Index), `value`.

#### [NEW] [isar_search_history.dart](file:///c:/cross_platform/mini_social/lib/core/database/collections/isar_search_history.dart)
- `@collection` cho lịch sử tìm kiếm: `id`, `query`, `timestamp`.

#### [NEW] [isar_post_draft.dart](file:///c:/cross_platform/mini_social/lib/core/database/collections/isar_post_draft.dart)
- `@collection` cho nháp bài viết: `id`, `content`, `localMediaPaths` (List<String>), `updatedAt`.

#### [NEW] [isar_sync_queue.dart](file:///c:/cross_platform/mini_social/lib/core/database/collections/isar_sync_queue.dart)
- `@collection` lưu hàng đợi các action mutation thực thi offline: `id`, `actionType` (sendMessage, likePost, createPost...), `payloadJson`, `createdAt`, `retryCount`.

#### [DELETE] [cached_conversation.dart](file:///c:/cross_platform/mini_social/lib/features/chat/data/collections/cached_conversation.dart)
#### [DELETE] [cached_message.dart](file:///c:/cross_platform/mini_social/lib/features/chat/data/collections/cached_message.dart)
#### [DELETE] [cached_profile.dart](file:///c:/cross_platform/mini_social/lib/features/chat/data/collections/cached_profile.dart)
#### [DELETE] [failed_message.dart](file:///c:/cross_platform/mini_social/lib/features/chat/data/collections/failed_message.dart)

---

### 4. Refactoring Repositories sang Offline-First Pattern

#### [MODIFY] [chat_repository.dart](file:///c:/cross_platform/mini_social/lib/features/chat/data/chat_repository.dart)
- Đọc tin nhắn & hội thoại từ Isar qua Reactive Streams `isar.isarConversations.where().watch()`.
- Ghi trực tiếp tin nhắn mới vào Isar (optimistic UI), đồng thời push vào `IsarSyncQueue` hoặc gửi trực tiếp lên Supabase nếu có mạng.
- Xử lý đồng bộ Supabase Realtime -> cập nhật ngay Isar.

#### [MODIFY] [post_repository.dart](file:///c:/cross_platform/mini_social/lib/features/feed/data/post_repository.dart)
- Đọc Feed từ Isar. Khi cuộn hoặc refresh, gọi Supabase lấy bài viết mới -> ghi vào Isar -> Stream Isar tự emit cho UI.
- Thao tác Like / Comment / Đăng bài offline -> ghi ngay Isar + thêm vào `IsarSyncQueue`.

#### [MODIFY] [profile_repository.dart](file:///c:/cross_platform/mini_social/lib/features/profile/data/profile_repository.dart)
- Đọc Profile người dùng hiện tại & người khác từ Isar. Cập nhật profile background sync khi online.

#### [MODIFY] [social_repository.dart](file:///c:/cross_platform/mini_social/lib/features/social/data/social_repository.dart)
- Đọc danh sách Thông báo từ Isar.

#### [MODIFY] [search_repository.dart](file:///c:/cross_platform/mini_social/lib/features/search/data/search_repository.dart)
- Đọc và ghi Lịch sử tìm kiếm vào `IsarSearchHistory`.

---

## 🧪 Verification Plan

### Automated Tests & Code Generation
1. Chạy `flutter pub get` để nạp các gói Isar & dependencies mới.
2. Chạy `dart run build_runner build --delete-conflicting-outputs` để sinh code `*.g.dart` cho Isar collections.
3. Chạy `flutter analyze` đảm bảo không còn lỗi syntax hoặc đúp import ObjectBox.

### Manual Verification
1. **Kiểm thử Web (IndexedDB)**:
   - Chạy `flutter run -d chrome`.
   - Mở DevTools -> Application -> IndexedDB -> Kiểm tra xem Isar DB có lưu bảng messages, conversations, feed không.
   - Bật Airplane mode / Offline Mode trong DevTools Network tab -> Thực hiện chuyển tab, xem tin nhắn, tạo bài viết nháp. Đảm bảo UI mượt mà không có icon xoay vô tận.
   - Bật lại Online -> Kiểm tra dữ liệu queued được đẩy lên Supabase.
2. **Kiểm thử Mobile (Android/iOS)**:
   - Chạy ứng dụng trên thiết bị thật / Emulator.
   - Tắt Wifi/4G -> Mở lại app -> Đảm bảo danh sách chat, tin nhắn, feed và thông báo hiển thị đầy đủ từ Isar local cache.
   - Xem ảnh / nghe Voice khi offline (đã xem trước đó) -> Đảm bảo `flutter_cache_manager` load thành công file local.
