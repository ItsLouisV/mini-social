# 🔍 Features — Đặc tả chi tiết

---

## 1. Authentication

### 1.1 Đăng ký
- Form: Email, Password, Full Name
- Validate: email hợp lệ, password ≥ 6 ký tự
- Sau khi đăng ký: Supabase gửi email xác nhận
- Trigger tự động tạo bản ghi `profiles`

### 1.2 Đăng nhập
- Form: Email + Password
- Hiển thị lỗi rõ ràng: sai mật khẩu, email chưa xác nhận
- Nhớ phiên đăng nhập (Supabase tự quản lý session qua SecureStorage)

### 1.3 Quên mật khẩu
- Nhập email → Supabase gửi link reset
- Hiển thị thông báo "Kiểm tra email của bạn"

### 1.4 Đăng xuất
- Gọi `supabase.auth.signOut()`
- Xóa state, redirect về `/login`

---

## 2. Profile

### 2.1 Xem hồ sơ
- Hiển thị: avatar, cover image, full name, username, bio
- Stats: số bài viết, số followers, số following
- Grid ảnh bài viết của user đó
- Nút Follow/Unfollow (nếu không phải profile của mình)

### 2.2 Chỉnh sửa profile
- Sửa: Full Name, Username, Bio
- Đổi Avatar: chọn ảnh từ thư viện → upload lên bucket `avatars`
  - Path: `avatars/{userId}/avatar.jpg`
- Đổi Cover: chọn ảnh từ thư viện → upload lên bucket `covers`
  - Path: `covers/{userId}/cover.jpg`
- Cập nhật bảng `profiles`

---

## 3. Feed & Posts

### 3.1 Feed
- **AppBar** hiển thị:
  - Bên trái: Logo hoặc text "MiniSocial"
  - Bên phải: Icon 🔍 → nhấn push `SearchScreen` (không mất bottom nav context)
- Hiển thị bài viết của những người mình đang follow (+ bài của chính mình)
- Query:
```sql
select posts.* from posts
where posts.user_id in (
  select following_id from follows where follower_id = auth.uid()
  union
  select auth.uid()
)
order by created_at desc
```
- Phân trang: `range(from, to)` của Supabase (20 bài/page)
- Mỗi PostCard hiển thị: avatar + tên user, caption, ảnh, số like, số comment, thời gian

### 3.2 Đăng bài
- Chọn ảnh từ thư viện (tối đa 5 ảnh)
- Nén ảnh trước khi upload
- Upload lên bucket `posts`: path `posts/{userId}/{uuid}.jpg`
- Lưu caption + mảng `media_urls` vào bảng `posts`

### 3.3 Xóa bài
- Chỉ hiển thị nút xóa trên bài của chính mình
- Xóa ảnh khỏi Storage + xóa record

---

## 4. Like & Comment

### 4.1 Like
- Tap icon tim → toggle like
- Optimistic update: UI đổi ngay, rollback nếu lỗi
- `likes_count` được cập nhật tự động qua trigger

### 4.2 Comment
- Mở bottom sheet hoặc navigate đến PostDetailScreen
- Hiển thị list comment: avatar, tên, nội dung, thời gian
- Input field ở dưới cùng để viết comment
- `comments_count` cập nhật tự động qua trigger

---

## 5. Follow & Notification

### 5.1 Follow
- FollowButton trên ProfileScreen: trạng thái "Theo dõi" / "Đang theo dõi"
- Loading state khi đang xử lý
- Cập nhật follower/following count ngay lập tức

### 5.2 Notification
- Realtime: subscribe `notifications` table qua Supabase Realtime
- Các loại thông báo:
  - `like`: "{user} đã thích bài viết của bạn"
  - `comment`: "{user} đã bình luận: {nội dung}"
  - `follow`: "{user} đã theo dõi bạn"
- Badge đỏ trên icon notification (số chưa đọc)
- Nhấn vào notification → navigate đến bài viết / profile tương ứng
- Mark as read khi mở NotificationScreen

---

## 6. Chat Realtime

### 6.1 Danh sách cuộc trò chuyện
- Hiển thị: avatar, tên người dùng, tin nhắn cuối, thời gian
- Sắp xếp theo `last_message_at` desc
- Tạo conversation mới khi nhấn message từ ProfileScreen

### 6.2 Chat Screen
- Load tin nhắn lịch sử (phân trang từ dưới lên)
- Subscribe Realtime channel: `messages:conversation_id=eq.{id}`
- Khi có tin nhắn mới → append vào list, auto scroll xuống
- Bubble: tin của mình (bên phải, màu primary), tin nhận được (bên trái, màu grey)
- Seen message:
  - Khi mở ChatScreen → mark tất cả tin nhắn chưa đọc là `is_seen = true`
  - Hiển thị "✓✓ Đã xem" dưới tin nhắn cuối của mình nếu đối phương đã xem
- Timestamp: hiển thị giờ gửi, nhóm theo ngày

---

## 7. Search User

> Được truy cập từ icon 🔍 trên AppBar của FeedScreen. Push lên stack, vẫn giữ bottom nav phía dưới.

- `SearchScreen` có `TextField` auto-focus khi mở
- Debounce 400ms trước khi gọi query (tránh gọi API liên tục khi gõ)
- Khi chưa gõ: hiển thị gợi ý "Tìm kiếm người dùng..."
- Khi đang gõ: hiển thị loading indicator
- Query:
```sql
select * from profiles
where username ilike '%{query}%'
   or full_name ilike '%{query}%'
limit 20
```
- Mỗi kết quả (`SearchUserTile`): avatar + full name + username + nút Follow/Unfollow
- Nhấn vào tile → navigate đến `ProfileScreen` của user đó

---

## 8. Extra Features

### 8.1 Dark Mode
- `ThemeNotifier` (StateNotifier) quản lý `ThemeMode`
- Lưu preference vào `SharedPreferences`
- Toggle switch trong Settings hoặc Profile

### 8.2 Story (Nâng cao)
- Bảng `stories`: id, user_id, media_url, created_at, expires_at (= created_at + 24h)
- Hiển thị stories trên đầu feed (horizontal scroll)
- StoryViewer: full screen, auto-advance, progress bar
- Đánh dấu story đã xem (bảng `story_views`)

### 8.3 Video Post
- Thêm hỗ trợ upload video (mp4) lên bucket `posts`
- `media_type = 'video'`
- Dùng `video_player` package để play trong PostCard/PostDetail

### 8.4 Voice Message
- Record audio với package `record`
- Upload file `.m4a` lên bucket `messages`
- `message_type = 'voice'`
- AudioPlayer widget với thanh progress và nút play/pause

---

## UI/UX Notes

- **Loading**: dùng Shimmer cho skeleton loading, không dùng spinner đơn giản
- **Error**: hiển thị SnackBar lỗi có nút Retry
- **Empty state**: illustration + text gợi ý hành động (ví dụ: "Chưa có bài viết nào. Hãy đăng bài đầu tiên!")
- **Image quality**: nén ảnh xuống còn ~800px width, quality 85% trước khi upload
- **Accessibility**: tất cả interactive widget có `tooltip` hoặc `semanticsLabel`
