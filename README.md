# 📱 MiniSocial — Flutter + Supabase

> Ứng dụng mạng xã hội mini xây dựng bằng **Flutter** & **Supabase**, theo phong cách UI/UX iOS.  
> Tính năng: Đăng bài, Like/Comment, Follow, Chat Realtime, Dark Mode.

---

## 🧰 Tech Stack

| Layer | Công nghệ |
|---|---|
| Frontend | Flutter (Dart) |
| Backend / DB | Supabase (PostgreSQL) |
| Auth | Supabase Auth |
| Storage | Supabase Storage |
| Realtime | Supabase Realtime |
| State Management | Riverpod |
| Navigation | GoRouter |

---

## 🚀 Hướng dẫn cài đặt và chạy dự án

### Yêu cầu hệ thống

Đảm bảo máy bạn đã cài đặt:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) **≥ 3.3.0**
- [Dart SDK](https://dart.dev/get-dart) **≥ 3.3.0** (đi kèm Flutter)
- [Git](https://git-scm.com/)
- Một trình giả lập (Android Emulator / iOS Simulator) hoặc thiết bị thật
- Tài khoản [Supabase](https://supabase.com/) (miễn phí)

---

### Bước 1 — Clone dự án

```bash
git clone https://github.com/your-username/mini_social.git
cd mini_social
```

---

### Bước 2 — Tạo dự án Supabase

1. Truy cập [supabase.com](https://supabase.com/) và tạo tài khoản / đăng nhập.
2. Nhấn **"New project"**, đặt tên và chọn region gần nhất.
3. Sau khi dự án khởi động xong, vào **Project Settings → API**.
4. Sao chép 2 giá trị sau:
   - **Project URL** (ví dụ: `https://xbmijnlq.supabase.co`)
   - **anon / public key**

---

### Bước 3 — Cấu hình file `.env`

Sao chép file mẫu và điền thông tin Supabase của bạn:

```bash
cp .env.example .env
```

Mở file `.env` vừa tạo và điền vào:

```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key_here
```

> **⚠️ Lưu ý bảo mật:** File `.env` đã được thêm vào `.gitignore` và sẽ **không** bị commit lên Git. Không bao giờ chia sẻ file `.env` chứa key thật của bạn lên public repository.

---

### Bước 4 — Thiết lập Database trên Supabase

Toàn bộ schema database nằm trong file [`DATABASE_SCHEMA.md`](./DATABASE_SCHEMA.md).

1. Trong Supabase Dashboard, mở **SQL Editor**.
2. Sao chép từng block SQL trong `DATABASE_SCHEMA.md` và chạy theo thứ tự từ trên xuống. Thứ tự quan trọng:
   - Tạo bảng `profiles`
   - Tạo bảng `posts`, `follows`, `likes`, `comments`
   - Tạo bảng `conversations`, `messages`
   - Tạo bảng `notifications`
   - Thêm các Trigger, Function và RLS Policies

#### 4a. Bật Realtime cho các bảng cần thiết

Sau khi tạo bảng xong, Realtime cần được bật thủ công:

1. Vào **Database → Replication** trong Supabase Dashboard.
2. Nhấn vào số bảng hiện tại (ví dụ: "0 tables") dưới mục **Source**.
3. Bật toggle ON cho các bảng: **`conversations`**, **`messages`**, **`notifications`**.

#### 4b. Thiết lập RLS (Row Level Security) bổ sung

Chạy đoạn SQL sau trong **SQL Editor** để cấp quyền cập nhật cho bảng `conversations` (cần thiết để trigger cập nhật `last_message` hoạt động đúng):

```sql
create policy "Participants can update conversations" on conversations
  for update using (auth.uid() = participant_1 or auth.uid() = participant_2);
```

---

### Bước 5 — Thiết lập Storage Buckets

Trong Supabase Dashboard, vào **Storage** và tạo các bucket sau (đặt chế độ **Public**):

| Bucket | Mục đích |
|---|---|
| `avatars` | Ảnh đại diện người dùng |
| `covers` | Ảnh bìa hồ sơ |
| `posts` | Ảnh/video bài đăng |
| `messages` | File đính kèm trong tin nhắn |

---

### Bước 6 — Cài đặt packages

```bash
flutter pub get
```

---

### Bước 7 — Chạy ứng dụng

```bash
# Chạy trên thiết bị / giả lập mặc định
flutter run

# Chạy trên Chrome (Web)
flutter run -d chrome --web-port=8080

# Chạy trên iOS Simulator (macOS)
flutter run -d ios

# Chạy trên Android Emulator
flutter run -d android
```

---

## 📁 Cấu trúc dự án

```
lib/
├── core/               # Config, constants, extensions, services
│   ├── constants/      # Supabase table names, etc.
│   ├── extensions/     # Date, string extensions
│   ├── router/         # GoRouter navigation config
│   └── services/       # SupabaseService wrapper
├── features/           # Các màn hình / tính năng chính
│   ├── auth/           # Đăng nhập, đăng ký, quên mật khẩu
│   ├── chat/           # Danh sách hội thoại, màn hình chat
│   ├── feed/           # Bảng tin, đăng bài, like/comment
│   ├── profile/        # Hồ sơ cá nhân, chỉnh sửa
│   ├── search/         # Tìm kiếm người dùng
│   └── social/         # Follow, notifications
├── shared/             # Widgets dùng chung (AppAvatar, etc.)
├── app.dart            # MaterialApp + ThemeData
└── main.dart           # Điểm khởi động ứng dụng
```

---

## ✨ Tính năng chính

| Tính năng | Mô tả |
|---|---|
| 🔐 Xác thực | Đăng ký / Đăng nhập / Quên mật khẩu qua email |
| 👤 Hồ sơ | Avatar, Cover, Bio, thống kê Follower / Following |
| 📰 Feed | Bài viết từ những người đang theo dõi với hiệu năng cực cao |
| ❤️ Like & Comment | Toggle like bài viết, bình luận theo thời gian thực |
| 💬 Thích bình luận | Tương tác thích bình luận riêng lẻ dạng gộp (Batch-fetch) & Optimistic UI |
| ⚡ Tối ưu Post Likes | Nạp trạng thái thích đồng bộ dạng gộp, triệt tiêu N+1 truy vấn và nhấp nháy UI |
| 📞 Gọi điện & Video | Gọi thoại / Video realtime chéo nền tảng (Web & Mobile) sử dụng WebRTC + LiveKit |
| 🤝 Follow | Theo dõi / bỏ theo dõi người dùng |
| 🔔 Thông báo | Realtime push khi có like, comment, follow mới |
| 💬 Chat | Nhắn tin 1-1 theo thời gian thực với Supabase Realtime |
| 🌙 Dark Mode | Toggle sáng / tối, lưu preference vào SharedPreferences |
| 🔍 Tìm kiếm | Tìm người dùng theo tên hoặc username |

---

## 🛠 Các lệnh hữu ích khác

```bash
# Kiểm tra phiên bản Flutter và môi trường
flutter doctor

# Build APK cho Android
flutter build apk --release

# Build cho iOS (chỉ trên macOS)
flutter build ios --release

# Chạy code generator (Riverpod annotations)
dart run build_runner build --delete-conflicting-outputs
```

---

## 📄 Tài liệu liên quan

- [`DATABASE_SCHEMA.md`](./DATABASE_SCHEMA.md) — Toàn bộ schema SQL, Triggers, RLS Policies
- [`FEATURES.md`](./FEATURES.md) — Đặc tả chi tiết từng tính năng
- [`FOLDER_STRUCTURE.md`](./FOLDER_STRUCTURE.md) — Cấu trúc thư mục chi tiết
- [`PROJECT_PLAN.md`](./PROJECT_PLAN.md) — Kế hoạch phát triển dự án

---

## ❓ Xử lý sự cố thường gặp

### Lỗi: `.env` không được tìm thấy
Đảm bảo bạn đã tạo file `.env` ở thư mục gốc của dự án (cùng cấp với `pubspec.yaml`) và chạy lại `flutter pub get`.

### Lỗi: `PostgrestException` khi tạo cuộc trò chuyện
Kiểm tra lại bảng `conversations` trong Supabase. Đảm bảo đã chạy SQL tạo constraint và policy UPDATE như hướng dẫn ở **Bước 4b**.

### Realtime không tự động cập nhật
Kiểm tra lại **Bước 4a**: các bảng `messages` và `conversations` phải được bật Realtime trong **Database → Replication** của Supabase Dashboard.

### Ảnh không upload được
Kiểm tra lại **Bước 5**: các Storage Buckets (`avatars`, `covers`, `posts`) phải được tạo với chế độ **Public** trên Supabase.
