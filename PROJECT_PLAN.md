# 📋 Project Plan — MiniSocial

> Kế hoạch phát triển theo sprint. Mỗi sprint ~3–4 ngày.

---

## Tổng quan tiến độ

| Sprint | Tên | Trạng thái |
|---|---|---|
| Sprint 1 | Setup & Authentication | ⬜ Chưa bắt đầu |
| Sprint 2 | Profile | ⬜ Chưa bắt đầu |
| Sprint 3 | Feed & Posts | ⬜ Chưa bắt đầu |
| Sprint 4 | Like & Comment | ⬜ Chưa bắt đầu |
| Sprint 5 | Follow & Notification | ⬜ Chưa bắt đầu |
| Sprint 6 | Chat Realtime | ⬜ Chưa bắt đầu |
| Sprint 7 | Polish, Search & Extra | ⬜ Chưa bắt đầu |

---

## Sprint 1 — Setup & Authentication

### Mục tiêu
Cài đặt dự án, kết nối Supabase, hoàn thiện luồng auth.

### Tasks

**Setup**
- [x] Khởi tạo Flutter project
- [ ] Thêm tất cả dependencies vào `pubspec.yaml`
- [ ] Tạo file `.env` và cấu hình `flutter_dotenv`
- [ ] Khởi tạo Supabase trong `main.dart`
- [ ] Cài đặt GoRouter với auth guard
- [ ] Cài đặt Riverpod (ProviderScope)
- [ ] Tạo `core/theme/app_theme.dart`

**Supabase**
- [ ] Tạo project Supabase
- [ ] Chạy SQL tạo bảng `profiles` + trigger
- [ ] Bật Email Auth

**Authentication**
- [ ] `AuthRepository`: signUp, signIn, signOut, resetPassword
- [ ] `authStateProvider` (StreamProvider)
- [ ] `LoginScreen` UI
- [ ] `RegisterScreen` UI
- [ ] `ForgotPasswordScreen` UI
- [ ] Redirect sau đăng nhập/đăng xuất

### Definition of Done
Người dùng có thể đăng ký, đăng nhập, đặt lại mật khẩu, đăng xuất.

---

## Sprint 2 — Profile

### Mục tiêu
Xem và chỉnh sửa hồ sơ cá nhân.

### Tasks

**Supabase**
- [ ] Tạo bucket `avatars` và `covers`
- [ ] Cài đặt Storage RLS policies

**Profile**
- [ ] `ProfileModel` (fromJson / toJson)
- [ ] `ProfileRepository`: getProfile, updateProfile, uploadAvatar, uploadCover
- [ ] `profileProvider` (FutureProvider.family)
- [ ] `ProfileScreen`: header, avatar, cover, stats (posts/followers/following), grid bài viết
- [ ] `EditProfileScreen`: form sửa tên, bio, đổi avatar, đổi cover
- [ ] Widget `AppAvatar` (cached)

### Definition of Done
Xem profile bất kỳ, chỉnh sửa profile của mình, đổi avatar/cover.

---

## Sprint 3 — Feed & Posts

### Mục tiêu
Đăng bài, xem feed, upload ảnh.

### Tasks

**Supabase**
- [ ] Tạo bảng `posts`
- [ ] Tạo bucket `posts`
- [ ] RLS cho posts

**Posts**
- [ ] `PostModel` (fromJson / toJson)
- [ ] `PostRepository`: createPost, getPosts, deletePost, uploadMedia
- [ ] `CreatePostScreen`: text caption + chọn ảnh (image_picker), preview, đăng
- [ ] `FeedScreen`: danh sách bài viết (infinite scroll với `infinite_scroll_pagination`)
- [ ] `PostCard` widget: avatar, caption, ảnh carousel, timestamp
- [ ] `PostDetailScreen`: xem chi tiết bài viết
- [ ] Shimmer loading khi tải feed

### Definition of Done
Đăng bài có ảnh, xem feed với phân trang, xóa bài của mình.

---

## Sprint 4 — Like & Comment

### Mục tiêu
Tương tác với bài viết.

### Tasks

**Supabase**
- [ ] Tạo bảng `likes` + trigger `likes_count`
- [ ] Tạo bảng `comments` + trigger `comments_count`
- [ ] RLS cho likes và comments

**Like**
- [ ] `likePost` / `unlikePost` trong PostRepository
- [ ] `isLikedProvider` (FutureProvider.family)
- [ ] `PostActions` widget: nút Like với animation, số like
- [ ] Optimistic update (cập nhật UI ngay, không chờ server)

**Comment**
- [ ] `CommentModel`
- [ ] `getComments` / `addComment` / `deleteComment`
- [ ] `commentsProvider`
- [ ] Comment list trong `PostDetailScreen`
- [ ] `CommentTile` widget
- [ ] Input gửi comment

### Definition of Done
Like/unlike bài viết, xem và viết comment.

---

## Sprint 5 — Follow & Notification

### Mục tiêu
Theo dõi người dùng, nhận thông báo.

### Tasks

**Supabase**
- [ ] Tạo bảng `follows`
- [ ] Tạo bảng `notifications` + enum type
- [ ] RLS cho follows và notifications
- [ ] Tạo DB functions để tự tạo notification khi like/comment/follow

**Follow**
- [ ] `followUser` / `unfollowUser` trong SocialRepository
- [ ] `isFollowingProvider`
- [ ] `FollowButton` widget (toggle, loading state)
- [ ] Hiển thị số followers/following trên ProfileScreen

**Notification**
- [ ] `NotificationModel`
- [ ] `notificationsProvider` (StreamProvider — Realtime)
- [ ] `NotificationScreen`: danh sách thông báo
- [ ] `NotificationTile`: avatar, text, timestamp, unread badge
- [ ] Badge số thông báo chưa đọc trên bottom nav

### Definition of Done
Follow/unfollow user, nhận thông báo realtime khi có like/comment/follow.

---

## Sprint 6 — Chat Realtime

### Mục tiêu
Chat 1-1 với seen message.

### Tasks

**Supabase**
- [ ] Tạo bảng `conversations` và `messages`
- [ ] Bucket `messages` (ảnh trong chat)
- [ ] RLS cho conversations và messages
- [ ] Bật Realtime cho bảng `messages`

**Chat**
- [ ] `ConversationModel`, `MessageModel`
- [ ] `ChatRepository`: getConversations, getMessages, sendMessage, markAsSeen, getOrCreateConversation
- [ ] `ConversationsScreen`: danh sách cuộc trò chuyện, preview tin nhắn cuối
- [ ] `ConversationTile` widget
- [ ] `ChatScreen`: danh sách tin nhắn, subscribe Realtime channel
- [ ] `MessageBubble` widget (sent/received, timestamp, seen indicator)
- [ ] `ChatInput` widget: text field + gửi
- [ ] Auto-scroll xuống tin nhắn mới nhất
- [ ] Mark as seen khi mở chat

### Definition of Done
Gửi nhận tin nhắn realtime, hiển thị "Đã xem".

---

## Sprint 7 — Polish, Search & Extra

### Mục tiêu
Hoàn thiện UX, thêm Search user và các tính năng bonus.

### Tasks (bắt buộc)
- [ ] **Search user**: `SearchScreen`, `SearchRepository` (ilike query), `SearchUserTile`, debounce 400ms
- [ ] Icon 🔍 trên AppBar của FeedScreen → push `SearchScreen`
- [ ] `FeedAppBar` widget tách riêng (logo + search icon)
- [ ] Dark mode (ThemeProvider, lưu vào SharedPreferences)
- [ ] Xử lý error states toàn bộ app
- [ ] Empty states (không có bài viết, không có thông báo...)
- [ ] Pull-to-refresh trên Feed và Notifications
- [ ] Loading skeleton (Shimmer) nhất quán
- [ ] Kiểm tra và fix các bug còn lại

### Tasks (extra — nếu còn thời gian)
- [ ] **Story**: bảng `stories` (tự xóa sau 24h qua `pg_cron` hoặc check timestamp), StoryViewer
- [ ] **Video post**: upload video lên bucket `posts`, VideoPlayer widget
- [ ] **Voice message**: record audio (`record` package), upload, AudioPlayer widget

### Definition of Done
App ổn định, search user hoạt động, dark mode hoạt động, UX mượt mà.

---

## Mốc nộp bài

| Mốc | Nội dung |
|---|---|
| Sprint 1–2 hoàn thành | Auth + Profile hoạt động |
| Sprint 3–4 hoàn thành | Feed + Post + Like + Comment |
| Sprint 5–6 hoàn thành | Follow + Notification + Chat |
| Sprint 7 hoàn thành | App hoàn chỉnh, nộp bài |

---

## Rủi ro & Giải pháp

| Rủi ro | Giải pháp |
|---|---|
| Supabase Realtime không ổn định | Retry logic + hiển thị trạng thái kết nối |
| Upload ảnh chậm | Nén ảnh trước khi upload (`flutter_image_compress`) |
| Phân trang phức tạp | Dùng `infinite_scroll_pagination` |
| RLS policy sai | Test kỹ từng policy bằng Supabase Studio |
