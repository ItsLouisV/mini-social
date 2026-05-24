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
- Hiển thị: avatar, cover image, full name, username, bio.
- Stats: số bài viết, số followers, số following.
- Grid ảnh bài viết của user đó.
- Nút Follow/Unfollow (nếu không phải profile của mình).
- **Màn hình Danh sách Kết nối (FollowListScreen)** ⭐ Mới:
  - Cho phép người dùng nhấp vào số lượng Người theo dõi (Followers) hoặc Đang theo dõi (Following) trên hồ sơ cá nhân để mở màn hình danh sách kết nối phong cách iOS.
  - Giao diện gồm 2 Tab: "Người theo dõi" và "Đang theo dõi" hiển thị danh sách người dùng tương ứng.
  - Hỗ trợ xem thông tin tóm tắt và thực hiện theo dõi/bỏ theo dõi tức thời bằng nút hành động ngay trên danh sách.

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
- Tap icon tim → toggle like bài viết.
- Optimistic update: UI đổi ngay lập tức (cả trạng thái trái tim lẫn số lượt thích), rollback nếu gặp lỗi.
- `likes_count` được cập nhật tự động qua trigger trên CSDL.

### 4.2 Comment
- Mở bottom sheet hoặc navigate đến PostDetailScreen.
- Hiển thị list comment: avatar, tên, nội dung, thời gian.
- Input field ở dưới cùng để viết comment.
- `comments_count` cập nhật tự động qua trigger trên CSDL.

### 4.3 Comment Likes (Thích bình luận) ⭐ Mới
- Cho phép người dùng thích/bỏ thích cho từng bình luận riêng lẻ.
- Tải gộp (batch-fetch) trạng thái thích của toàn bộ bình luận trong bài viết trong 1 truy vấn duy nhất qua Supabase `.inFilter()` để tăng tốc độ nạp dữ liệu.
- Phản hồi tức thời (Optimistic UI) cập nhật số lượt thích và trạng thái ngay lập tức trên UI trước khi lưu xuống DB.

### 4.4 Tối ưu hoá Thích bài viết (Post Likes Optimization) ⭐ Mới
- Luồng thích bài viết được refactor đồng bộ hóa hoàn toàn và áp dụng cơ chế tải gộp dữ liệu (batch-fetching).
- Toàn bộ danh sách bài viết trên Bảng tin (Feed) và trang cá nhân (Profile) đều nạp trạng thái thích cùng lúc trong một truy vấn CSDL duy nhất.
- Triệt tiêu 100% hiện tượng nhấp nháy UI khi tải danh sách và loại bỏ hoàn toàn N+1 truy vấn mạng.

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

## 6. Chat Realtime & Advanced Messaging ⭐ Cập nhật

### 6.1 Danh sách cuộc trò chuyện (Conversations List)
- Hiển thị: avatar, tên người dùng, tin nhắn cuối, thời gian, và dấu tròn xanh thông báo có tin nhắn chưa đọc.
- Sắp xếp: Tự động sắp xếp các cuộc hội thoại được Ghim lên trên cùng đầu danh sách, các cuộc hội thoại còn lại sắp xếp theo thời gian tin nhắn cuối (`last_message_at`) giảm dần.
- Tạo hội thoại mới nhanh: Nhấp icon Bút viết góc trên AppBar mở modal tìm kiếm/chọn nhanh bạn bè để bắt đầu chat.
- **Quản lý bằng cử chỉ vuốt cực mượt (Cupertino & Slidable Gestures)** ⭐ Mới:
  - **Vuốt từ Trái -> Phải**: Ghim / Bỏ ghim cuộc trò chuyện (`togglePin`). Cuộc trò chuyện được ghim sẽ đổi màu nền nhẹ nhàng, hiển thị icon ghim nhỏ xinh và luôn được đẩy lên đầu.
  - **Vuốt từ Phải -> Trái**:
    - **Ẩn (Hide)**: Chuyển cuộc trò chuyện vào danh mục "Đoạn chat bị ẩn" để bảo vệ sự riêng tư.
    - **Xóa (Delete)**: Hiện hội thoại xác nhận (CupertinoDialog) để xóa vĩnh viễn cuộc trò chuyện khỏi CSDL ở cả 2 phía.

### 6.2 Bảo mật riêng tư (Mã khóa đoạn chat bị ẩn) ⭐ Mới
- **Passcode Lock cho đoạn chat bị ẩn** (`/chat/hidden`):
  - Khi mở danh sách đoạn chat bị ẩn, bắt buộc người dùng phải nhập đúng Passcode (Mã khóa bảo mật 6 chữ số) mới được xem.
  - Hỗ trợ luồng Thiết lập Passcode lần đầu (`PasscodeMode.setup`) và Xác minh Passcode cho những lần truy cập sau (`PasscodeMode.verify`).
  - Tự động gỡ bỏ passcode nếu không còn bất kỳ cuộc trò chuyện bị ẩn nào nữa để tối giản trải nghiệm.

### 6.3 Chat Screen & Advanced Messages Actions
- Load tin nhắn lịch sử (phân trang mượt mà từ dưới lên bằng offset).
- Đăng ký realtime nhận tin nhắn tức thời: `messages:conversation_id=eq.{id}`.
- Bubble tin nhắn thông minh: Trình bày đẹp mắt theo phong cách iOS (tin nhắn của mình bên phải màu primary/gradient, tin nhắn nhận được bên trái màu xám nhạt).
- Trạng thái tin nhắn đã xem (Seen status):
  - Tự động đánh dấu `is_seen = true` cho mọi tin nhắn khi mở ChatScreen.
  - Hiển thị trạng thái "✓✓ Đã xem" kèm thời gian xem cực kỳ chi tiết dưới tin nhắn cuối cùng nếu đối phương đã xem.
- **Các tính năng tin nhắn nâng cao** ⭐ Mới:
  - **Ghim tin nhắn trong cuộc trò chuyện (Message Pinning)**: Cho phép ghim một hoặc nhiều tin nhắn quan trọng trong phòng chat.
  - **Thanh ghim tin nhắn (Pinned Messages Bar)**: Hiển thị nổi bật ở đầu phòng chat, hỗ trợ thu gọn/mở rộng danh sách ghim.
  - **Nhảy đến tin nhắn ghim (Jump to pinned message)**: Khi bấm vào tin nhắn ghim, hệ thống tự động tải "cửa sổ tin nhắn" (Message Window) bao gồm các tin nhắn cũ hơn và mới hơn xung quanh thời điểm ghim và tự động cuộn (scroll) mượt mà đến đúng vị trí tin nhắn đó.
  - **Trả lời tin nhắn (Reply message)**: Cho phép trích dẫn, phản hồi và nhấp vào tin nhắn trích dẫn để tự động nhảy đến vị trí gốc.
  - **Gửi hình ảnh kèm chú thích (Image with caption)**: Người dùng có thể đính kèm ảnh chụp trực tiếp hoặc từ thư viện và điền thêm text chú thích (caption) khi gửi tin nhắn.

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

### 8.1 Settings & Profile Banner (Cupertino Grouped Style) ⭐ Cập nhật
- Giao diện cài đặt phân nhóm (Grouped style) phong cách đặc trưng của iOS.
- **Apple-ID Style Profile Banner**: Hiển thị avatar cỡ lớn, tên hiển thị và liên kết dẫn đến trang thông tin cấu hình tài khoản chi tiết.
- Quản lý chế độ sáng/tối (Dark Mode) bằng nút công tắc `CupertinoSwitch` phản hồi trực quan ngay lập tức.
- Xem chi tiết phiên bản ứng dụng, hỗ trợ chuyển đổi ngôn ngữ (Tiếng Việt) và liên kết Trợ giúp/Hỗ trợ.

### 8.2 iOS Frosted-Glass Navigation & Stateful Shell Route ⭐ Mới
- Sử dụng `StatefulShellRoute.indexedStack` của GoRouter để tạo ra thanh điều hướng 5 Tab mượt mà. 
- Mỗi Tab (Feed, Chat, Create Post, Notifications, Settings) duy trì một Navigator Stack riêng biệt, giúp giữ nguyên trạng thái trang của từng tab khi người dùng chuyển tab.
- Thanh TabBar phong cách iOS (`_IosTabBar`) với hiệu ứng kính mờ (frosted-glass) bằng công nghệ HSL alpha blending.
- Tự động hiển thị huy hiệu đỏ đếm số tin nhắn chưa đọc (`unreadMsgCount`) và thông báo chưa đọc (`unreadNotifCount`) theo thời gian thực đồng bộ chéo giữa các màn hình.

### 8.3 Story (Nâng cao)
- Bảng `stories`: id, user_id, media_url, created_at, expires_at (= created_at + 24h)
- Hiển thị stories trên đầu feed (horizontal scroll)
- StoryViewer: full screen, auto-advance, progress bar
- Đánh dấu story đã xem (bảng `story_views`)

### 8.4 Video Post
- Thêm hỗ trợ upload video (mp4) lên bucket `posts`
- `media_type = 'video'`
- Dùng `video_player` package để play trong PostCard/PostDetail

### 8.5 Voice Message
- Record audio với package `record`
- Upload file `.m4a` lên bucket `messages`
- `message_type = 'voice'`
- AudioPlayer widget với thanh progress và nút play/pause

### 8.6 Calling & Video Call (Cuộc gọi thoại & Video) ⭐ Mới
- Tích hợp giải pháp WebRTC thông qua LiveKit Cloud và Supabase Edge Functions để tạo các phòng gọi điện realtime chéo nền tảng (Web ↔ Android/iOS).
- **Màn hình gọi đi (Outgoing Call Screen)**: Khởi tạo phòng LiveKit duy nhất bằng UUID, đổ chuông (dial tone) và tự động đếm ngược 60 giây chờ Callee nhấc máy.
- **Màn hình cuộc gọi đến (Incoming Call Screen)**: Nhận cuộc gọi realtime qua cơ chế lắng nghe của Supabase Realtime tại root widget, phát nhạc chuông (ringtone) kèm theo thông tin người gọi để người dùng có thể nhấc máy hoặc từ chối mọi lúc mọi nơi.
- **Màn hình cuộc gọi hoạt động (Active Call Screen)**: Bật/Tắt Mic và Camera linh hoạt, hiển thị camera của bản thân ở góc nhỏ và luồng video người kia toàn màn hình. Có đồng hồ đếm thời gian thực và tự động lưu thông tin thời lượng cuộc gọi vào CSDL sau khi kết thúc.

---

## UI/UX Notes

- **Loading**: dùng Shimmer cho skeleton loading, không dùng spinner đơn giản
- **Error**: hiển thị SnackBar lỗi có nút Retry
- **Empty state**: illustration + text gợi ý hành động (ví dụ: "Chưa có bài viết nào. Hãy đăng bài đầu tiên!")
- **Image quality**: nén ảnh xuống còn ~800px width, quality 85% trước khi upload
- **Accessibility**: tất cả interactive widget có `tooltip` hoặc `semanticsLabel`
