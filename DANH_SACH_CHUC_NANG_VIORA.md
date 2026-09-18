# 📱 TÀI LIỆU RÀ SOÁT & ĐẶC TẢ CHI TIẾT TẤT CẢ CHỨC NĂNG DỰ ÁN VIORA

> **Tên dự án:** Viora (Tiền thân: MiniSocial)  
> **Phiên bản hiện tại:** 2.1.1 (Production-Ready)  
> **Loại ứng dụng:** Mạng xã hội đa nền tảng (Cross-Platform Social Network)  
> **Nền tảng hỗ trợ:** Android, iOS, Web (Desktop & Mobile Browser)  
> **Ngày rà soát & lập tài liệu:** 10/09/2026  

---

## 📑 MỤC LỤC TỔNG QUAN

1. [Tổng quan dự án & Ngăn xếp công nghệ (Tech Stack)](#1-tổng-quan-dự-án--ngăn-xếp-công-nghệ)
2. [Bảng ma trận tổng hợp các phân hệ chức năng](#2-bảng-ma-trận-tổng-hợp-các-phân-hệ-chức-năng)
3. [Phân hệ 1: Xác thực & Quản trị bảo mật tài khoản (Authentication & Security)](#3-phân-hệ-1-xác-thực--quản-trị-bảo-mật-tài-khoản)
4. [Phân hệ 2: Hồ sơ người dùng, Kết nối & Mã QR (Profile, Connections & QR)](#4-phân-hệ-2-hồ-sơ-người-dùng-kết-nối--mã-qr)
5. [Phân hệ 3: Bảng tin, Bài viết & Đa phương tiện (Feed, Posts & Rich Media)](#5-phân-hệ-3-bảng-tin-bài-viết--đa-phương-tiện)
6. [Phân hệ 4: Tin ngắn 24 giờ (Stories 24h)](#6-phân-hệ-4-tin-ngắn-24-giờ-stories-24h)
7. [Phân hệ 5: Nhắn tin thời gian thực & Quản lý nhóm (Chat, Realtime Messaging & Groups)](#7-phân-hệ-5-nhắn-tin-thời-gian-thực--quản-lý-nhóm)
8. [Phân hệ 6: Cuộc gọi thoại & Video Call WebRTC (Calling Feature)](#8-phân-hệ-6-cuộc-gọi-thoại--video-call-webrtc)
9. [Phân hệ 7: Tìm kiếm, Khám phá & Trí tuệ nhân tạo (Search & AI Discovery)](#9-phân-hệ-7-tìm-kiếm-khám-phá--trí-tuệ-nhân-tạo)
10. [Phân hệ 8: Thông báo thời gian thực & Huy hiệu (Realtime Notifications & Badges)](#10-phân-hệ-8-thông-báo-thời-gian-thực--huy-hiệu)
11. [Phân hệ 9: An toàn cộng đồng, Kiểm duyệt & Khiếu nại (Trust, Safety & Moderation)](#11-phân-hệ-9-an-toàn-cộng-đồng-kiểm-duyệt--khiếu-nại)
12. [Phân hệ 10: Kiến trúc Ngoại tuyến & Đồng bộ dữ liệu (Offline-First & Sync Engine)](#12-phân-hệ-10-kiến-trúc-ngoại-tuyến--đồng-bộ-dữ-liệu)
13. [Phân hệ 11: Cài đặt hệ thống, Đa ngôn ngữ & Giao diện (Settings & Cupertino UI/UX)](#13-phân-hệ-11-cài-đặt-hệ-thống-đa-ngôn-ngữ--giao-diện)
14. [Tổng kết tài nguyên & Kiến trúc Backend Supabase](#14-tổng-kết-tài-nguyên--kiến-trúc-backend-supabase)

---

## 1. TỔNG QUAN DỰ ÁN & NGĂN XẾP CÔNG NGHỆ

### 1.1 Mục tiêu sản phẩm
**Viora** là một nền tảng mạng xã hội hiện đại, mượt mà theo ngôn ngữ thiết kế **iOS Cupertino**, chú trọng trải nghiệm người dùng cao cấp, tính bảo mật cao, khả năng tương tác thời gian thực tức thì và kiến trúc hoạt động ngoại tuyến (**Offline-First**) giúp người dùng có thể sử dụng ứng dụng mọi lúc, mọi nơi ngay cả khi mất mạng.

### 1.2 Ngăn xếp công nghệ (Tech Stack)

| Thành phần | Công nghệ / Thư viện | Vai trò |
|:---|:---|:---|
| **Client Framework** | Flutter 3.3+ / Dart SDK `>=3.3.0 <4.0.0` | Đa nền tảng (Android, iOS, Web Chrome/Safari/Edge) |
| **State Management** | `flutter_riverpod` (v2.5.1), `riverpod_annotation` | Quản lý trạng thái phân lớp, Dependency Injection, Reactive |
| **Routing / Điều hướng** | `go_router` (v14.0.0) | Điều hướng khai báo, `StatefulShellRoute` giữ trạng thái Tab |
| **Backend as a Service** | Supabase (`supabase_flutter` v2.5.0) | PostgreSQL 15, Supabase Auth, Storage CDN, Realtime WebSocket |
| **Edge Compute** | Supabase Edge Functions (Deno / TypeScript) | Xử lý logic máy chủ bảo mật, LiveKit token, AI, Recommendation |
| **Gọi điện & Video Call** | LiveKit Cloud WebRTC (`livekit_client` v2.11.0) | Phòng gọi WebRTC chuẩn đa nền tảng (Web ↔ Mobile) |
| **Local Database (Mobile)** | Isar Database (`isar: ^3.1.0+1`) | Cơ sở dữ liệu NoSQL cục bộ tốc độ cao cho Android/iOS |
| **Local Database (Web)** | Hive (`hive_flutter: ^1.1.0`) / IndexedDB | Lưu trữ cục bộ trên trình duyệt Web |
| **Caching & Rate Limiting** | Upstash Redis | Redis REST API quản lý lượt truy cập, presence, cache server |
| **Trí tuệ nhân tạo (AI)** | Google Gemini (Vision & Text) | Tự động tạo caption ảnh, kiểm duyệt nội dung đa tầng, Hybrid search |
| **Âm thanh & Thu âm** | `record` (v6.0.0), `audioplayers` (v6.1.0) | Ghi âm tin nhắn thoại, phát nhạc nền iTunes, nhạc chuông cuộc gọi |
| **Mã QR & Quét Camera** | `mobile_scanner`, `google_mlkit_barcode_scanning`, `qr_flutter` | Tạo mã QR định danh, quét QR camera & đọc từ thư viện ảnh |
| **Vị trí & Địa lý** | `geolocator`, `exif` | Lấy tọa độ GPS thiết bị, đọc tọa độ từ thẻ EXIF ảnh chụp |
| **Giám sát & Báo lỗi** | `sentry_flutter` (v8.13.0) | Crash analytics, giám sát lỗi thời gian thực |

---

## 2. BẢNG MA TRẬN TỔNG HỢP CÁC PHÂN HỆ CHỨC NĂNG

Dự án gồm **11 phân hệ chính** với hơn **55 tính năng nghiệp vụ** hoàn chỉnh:

```
Viora Core Platform
 ├── 1. Xác thực & Bảo mật tài khoản (8 tính năng)
 ├── 2. Hồ sơ người dùng & Quan hệ xã hội (10 tính năng)
 ├── 3. Bảng tin, Bài viết & Đa phương tiện (17 tính năng)
 ├── 4. Tin ngắn 24 giờ - Stories (5 tính năng)
 ├── 5. Nhắn tin Realtime & Quản lý nhóm (19 tính năng)
 ├── 6. Cuộc gọi thoại & Video Call WebRTC (5 tính năng)
 ├── 7. Tìm kiếm, Đề xuất & AI (4 tính năng)
 ├── 8. Thông báo thời gian thực & Huy hiệu (4 tính năng)
 ├── 9. An toàn cộng đồng, Kiểm duyệt & Khiếu nại (7 tính năng)
 ├── 10. Kiến trúc Ngoại tuyến & Đồng bộ Sync Engine (5 tính năng)
 └── 11. Cài đặt hệ thống, Đa ngôn ngữ & Giao diện (9 tính năng)
```

---

## 3. PHÂN HỆ 1: XÁC THỰC & QUẢN TRỊ BẢO MẬT TÀI KHOẢN

### 3.1 Đăng ký tài khoản (Register)
- **Màn hình:** `RegisterScreen` (`/register`)
- **Mô tả:** Người dùng tạo tài khoản mới bằng Email, Mật khẩu và Tên hiển thị (Full Name).
- **Quy tắc & Nghiệp vụ:**
  - Kiểm tra định dạng Email hợp lệ qua regex.
  - Mật khẩu tối thiểu 6 ký tự.
  - Tự động tạo bản ghi hồ sơ cá nhân (`profiles`) thông qua Database Trigger PostgreSQL trên Supabase ngay khi user đăng ký thành công.
  - Giao diện có hiệu ứng chuyển cảnh Cupertino vuốt trượt từ dưới lên (Slide Transition).

### 3.2 Đăng nhập (Login)
- **Màn hình:** `LoginScreen` (`/login`)
- **Mô tả:** Hỗ trợ đăng nhập linh hoạt bằng **Email** hoặc **Tên người dùng (Username)** kết hợp mật khẩu.
- **Quy tắc & Nghiệp vụ:**
  - Tự động phát hiện người dùng nhập username để truy vấn email tương ứng qua RPC `get_email_by_username` trước khi xác thực với Supabase Auth.
  - Lưu phiên đăng nhập an toàn vào bộ nhớ mã hóa thiết bị (`flutter_secure_storage`).
  - Xử lý và hiển thị thông báo lỗi chi tiết: Sai mật khẩu, tài khoản chưa kích hoạt, hoặc tài khoản đang bị tạm khóa do vi phạm tiêu chuẩn cộng đồng.

### 3.3 Quên mật khẩu & Đặt lại (Forgot Password)
- **Màn hình:** `ForgotPasswordScreen` (`/forgot-password`)
- **Mô tả:** Cho phép người dùng nhập địa chỉ email đã đăng ký để nhận liên kết đặt lại mật khẩu an toàn từ Supabase.
- **Quy tắc & Nghiệp vụ:** Gửi email xác thực kèm token reset, kiểm tra trạng thái gửi và hiển thị giao diện hướng dẫn người dùng kiểm tra hòm thư.

### 3.4 Đổi mật khẩu (Change Password)
- **Màn hình:** `ChangePasswordScreen` (`/settings/change-password`)
- **Mô tả:** Dành cho người dùng đã đăng nhập muốn cập nhật mật khẩu mới trong phần cài đặt bảo mật.
- **Quy tắc & Nghiệp vụ:** Yêu cầu nhập mật khẩu hiện tại, mật khẩu mới và xác nhận lại mật khẩu mới. Kiểm tra độ mạnh mật khẩu trước khi gọi `supabase.auth.updateUser()`.

### 3.5 Xác thực đa yếu tố 2FA / MFA (Two-Factor Authentication)
- **Màn hình:** `TwoFactorAuthScreen` (`/settings/two-factor`)
- **Mô tả:** Cho phép người dùng nâng cấp bảo mật tài khoản bằng phương thức TOTP (Time-based One-Time Password) chuẩn Google Authenticator / Apple Keychain / Authy.
- **Quy tắc & Nghiệp vụ:**
  - Tạo bí mật MFA qua Supabase Auth MFA API (`mfa.enroll()`).
  - Hiển thị mã QR để quét vào ứng dụng Authenticator, cùng mã khóa dự phòng (Secret Key) để nhập thủ công.
  - Nhập mã 6 số đầu tiên để kích hoạt thành công trạng thái 2FA (`aal2`).
  - Cho phép hủy kích hoạt (Unenroll) khi không còn nhu cầu.

### 3.6 Màn hình xác minh bước 2 (MFA Verification Screen)
- **Màn hình:** `MfaVerificationScreen` (`/mfa-verify`)
- **Mô tả:** Khi tài khoản đã bật 2FA đăng nhập vào hệ thống, ứng dụng sẽ chặn tại màn hình này và yêu cầu mã TOTP 6 số.
- **Quy tắc & Nghiệp vụ:**
  - `app_router.dart` tự động kiểm tra `AuthenticatorAssuranceLevels`: nếu cấp hiện tại là `aal1` mà cấp yêu cầu là `aal2`, router sẽ bắt buộc redirect về `/mfa-verify`.
  - Hỗ trợ tính năng tự động nhảy ô nhập mã, xóa lùi, dán clipboard mã OTP 6 số.

### 3.7 Quản lý thiết bị đăng nhập & Phiên hoạt động (Device Management)
- **Màn hình:** `DeviceManagementScreen` (`/settings/devices`)
- **Mô tả:** Liệt kê toàn bộ các thiết bị và phiên làm việc (sessions) đang đăng nhập vào tài khoản của người dùng.
- **Quy tắc & Nghiệp vụ:**
  - Thu thập thông tin phiên: Hệ điều hành (Android, iOS, Web/Windows/macOS), IP đăng nhập, Trình duyệt, Thời điểm hoạt động gần nhất.
  - Phân biệt rõ "Thiết bị hiện tại" (Current Device) và "Thiết bị khác".
  - Cho phép **Đăng xuất từ xa (Revoke Session)** đối với từng thiết bị riêng lẻ, hoặc bấm nút **"Đăng xuất khỏi tất cả thiết bị khác"** để bảo vệ tài khoản khi bị nghi ngờ lộ mật khẩu.

### 3.8 Đăng xuất & Quản lý vòng đời phiên (Sign Out)
- **Mô tả:** Thực hiện gọi `authRepository.signOut()`.
- **Quy tắc & Nghiệp vụ:** Xóa toàn bộ token session, xóa cache cục bộ tạm thời, đóng các kênh Supabase Realtime Channels và điều hướng người dùng về màn hình đăng nhập `/login`.

---

## 4. PHÂN HỆ 2: HỒ SƠ NGƯỜI DÙNG, KẾT NỐI & MÃ QR

### 4.1 Xem trang cá nhân (Profile Screen)
- **Màn hình:** `ProfileScreen` (`/profile/me` hoặc `/profile/:userId`)
- **Mô tả:** Hiển thị thông tin tổng quan của bản thân hoặc người dùng khác trong mạng xã hội.
- **Chi tiết giao diện & dữ liệu:**
  - **Ảnh bìa (Cover Image):** Ảnh cover dạng banner rộng, có hiệu ứng gradient phủ mờ.
  - **Ảnh đại diện (Avatar):** Hiển thị avatar tròn viền sáng, fallback chữ cái đầu nếu chưa đặt ảnh.
  - **Thông tin:** Tên hiển thị (Display Name), Tên định danh (`@username`), Tiểu sử (Bio), Huy hiệu tài khoản.
  - **Số liệu thống kê (Stats Bar):** Số bài viết, Số người theo dõi (Followers), Số người đang theo dõi (Following), Số bạn bè (Friends).
  - **Nhạc nền cá nhân:** Widget nghe thử bài hát yêu thích do chủ tài khoản cài đặt.
  - **Lưới bài viết cá nhân:** Lưới ảnh 3 cột (Grid View) thể hiện toàn bộ ảnh/video các bài đăng của người dùng, phân trang cuộn mượt.
  - **Nút hành động:**
    - Nếu là trang của mình: Nút "Chỉnh sửa hồ sơ", nút "Mã QR của tôi".
    - Nếu là người khác: Nút Theo dõi/Bỏ theo dõi (Follow/Unfollow), Nút Kết bạn (Add Friend / Pending / Friends), Nút Nhắn tin (mở phòng chat trực tiếp), Menu ba chấm (Báo cáo, Chặn).

### 4.2 Chỉnh sửa hồ sơ cá nhân (Edit Profile)
- **Màn hình:** `EditProfileScreen` (`/profile/edit`)
- **Mô tả:** Cho phép cập nhật thông tin cá nhân và thay đổi ảnh đại diện, ảnh bìa.
- **Nghiệp vụ:**
  - Thay đổi Avatar: Chọn ảnh từ máy ảnh hoặc thư viện -> Tự động nén ảnh tối ưu -> Tải lên Storage Bucket `avatars` theo đường dẫn `avatars/{userId}/avatar.jpg`.
  - Thay đổi Cover: Tương tự nén và tải lên Storage Bucket `covers` theo đường dẫn `covers/{userId}/cover.jpg`.
  - Cập nhật Tên hiển thị, Tên người dùng (`@username` duy nhất), Tiểu sử (Bio tối đa 150 ký tự), Chọn nhạc nền hồ sơ.

### 4.3 Nhạc nền trang cá nhân (Profile Music Track)
- **Widget:** `ProfileMusicCard` tích hợp trên `ProfileScreen`
- **Mô tả:** Người dùng có thể chọn một bài hát tâm đắc từ iTunes để làm nhạc nền đại diện cho trang cá nhân của mình.
- **Nghiệp vụ:**
  - Hiển thị bìa album thu nhỏ, tên bài hát, tên nghệ sĩ, đĩa xoay vinyl sinh động.
  - Nhấn nút Play để phát đoạn nhạc xem trước (30s Audio Preview) chất lượng cao bằng `AppAudioPlayer`.

### 4.4 Danh sách Người theo dõi & Đang theo dõi (Follow List Screen)
- **Màn hình:** `FollowListScreen` (`/profile/:userId/follows?tab=followers|following`)
- **Mô tả:** Giao diện phân nhóm 2 Tab phong cách iOS hiển thị danh sách người theo dõi và người mình đang theo dõi.
- **Nghiệp vụ:**
  - Hỗ trợ xem thông tin tóm tắt từng người (Avatar, Tên, Username).
  - Nút hành động trực tiếp ngay trên từng dòng: Theo dõi lại / Đang theo dõi / Bỏ theo dõi với phản hồi tức thì (Optimistic UI).

### 4.5 Danh sách Bạn bè & Lời mời kết bạn (Friends List Screen)
- **Màn hình:** `FriendsListScreen` (`/profile/:userId/friends?tab=friends|pending|sent`)
- **Mô tả:** Quản lý mối quan hệ bạn bè 2 chiều (Mutual Friendship).
- **Nghiệp vụ:**
  - Tab 1 - Bạn bè: Những người đã chấp nhận kết bạn của nhau.
  - Tab 2 - Lời mời đã nhận (Pending): Danh sách người khác gửi lời mời kết bạn đến mình -> Hỗ trợ nút "Chấp nhận" hoặc "Từ chối".
  - Tab 3 - Lời mời đã gửi (Sent): Danh sách các lời mời mình đã gửi đi -> Hỗ trợ nút "Thu hồi lời mời".

### 4.6 Mã QR cá nhân (My QR Code Screen)
- **Màn hình:** `MyQrCodeScreen` (`/my-qr`)
- **Mô tả:** Tạo mã QR Code độc quyền định danh hồ sơ người dùng để chia sẻ offline ngoài đời thực.
- **Nghiệp vụ:**
  - Mã hóa URI định danh theo format `viora://profile/{userId}` hoặc link web trực tiếp.
  - Nhúng Avatar của người dùng vào chính giữa mã QR.
  - Nút "Lưu ảnh vào thư viện" và nút "Chia sẻ mã QR" qua các ứng dụng khác.

### 4.7 Bộ quét mã QR thông minh (QR Scanner Screen)
- **Màn hình:** `QrScannerScreen` (`/qr-scan`)
- **Mô tả:** Quét mã QR của người khác để tìm kiếm và kết bạn tức thời mà không cần gõ tên.
- **Nghiệp vụ:**
  - Quét qua Camera: Sử dụng `mobile_scanner` / `google_mlkit_barcode_scanning` với giao diện khung quét radar công nghệ cao, hỗ trợ bật/tắt đèn Flash.
  - Quét từ thư viện ảnh: Tích hợp bộ giải mã ảnh `qr_image_decoder.dart` chạy mượt mà trên cả Mobile lẫn Flutter Web.

### 4.8 Xem trước hồ sơ nhanh qua QR (QR Profile Bottom Sheet)
- **Widget:** `QrProfileBottomSheet`
- **Mô tả:** Khi camera hoặc bộ giải mã nhận diện thành công mã QR tài khoản, một BottomSheet mượt mà sẽ trượt lên hiển thị avatar, họ tên, bio và 2 nút hành động nhanh: "Theo dõi ngay" và "Xem trang cá nhân đầy đủ".

### 4.9 Thiết lập quyền riêng tư (Privacy Settings)
- **Màn hình:** `PrivacySettingsScreen` (`/settings/privacy`)
- **Mô tả:** Tùy biến cấp độ hiển thị và sự an toàn của tài khoản.
- **Tùy chọn:**
  - **Tài khoản riêng tư (Private Account):** Khi bật, chỉ những người theo dõi được chủ tài khoản phê duyệt mới có thể xem các bài viết trên trang cá nhân.
  - **Ai có thể nhắn tin cho bạn:** Mọi người (Everyone) / Chỉ người theo dõi & bạn bè (Followers) / Không ai cả (Nobody).
  - **Ai có thể bình luận bài viết của bạn:** Mọi người / Người theo dõi / Bạn bè.
  - **Hiển thị trạng thái hoạt động (Activity Status):** Bật/tắt trạng thái chấm xanh online.

### 4.10 Danh sách chặn & Bỏ chặn (Blocked Users)
- **Mô tả:** Xem danh sách người dùng mà mình đã chặn trong cài đặt riêng tư.
- **Nghiệp vụ:** Chặn 2 chiều toàn diện: Khi A chặn B, cả hai bên đều không thể tìm thấy trang cá nhân của nhau, bài viết trên bảng tin bị triệt tiêu 100%, không thể nhắn tin hay gọi điện cho nhau. Hỗ trợ nút "Bỏ chặn" (Unblock) để khôi phục trạng thái.

---

## 5. PHÂN HỆ 3: BẢNG TIN, BÀI VIẾT & ĐA PHƯƠNG TIỆN

### 5.1 Bảng tin thông minh (Feed Screen)
- **Màn hình:** `FeedScreen` (`/feed`)
- **Mô tả:** Màn hình trang chủ chính của ứng dụng, tổng hợp các bài viết mới nhất từ bạn bè, người đang theo dõi và các bài viết đề xuất chất lượng cao.
- **Đặc điểm nổi bật:**
  - **Thanh AppBar linh hoạt:** Tích hợp logo Viora, icon Mở Drawer menu bên trái, icon Tìm kiếm và danh sách Stories 24h trên cùng.
  - **Cuộn vô hạn (Infinite Scroll):** Tự động tải trang kế tiếp khi người dùng cuộn đến gần cuối trang.
  - **Kéo để làm mới (Pull-to-Refresh):** Vuốt từ trên xuống để làm mới bảng tin và nạp bài viết mới nhất.
  - **Hiệu ứng Shimmer Skeleton:** Hiển thị khung xương bài viết khi đang tải dữ liệu, không dùng spinner nhàm chán.

### 5.2 Thuật toán xếp hạng Bảng tin (Recommendation Engine v2)
- **Kiến trúc:** Supabase Edge Function `recommendation-engine` kết hợp PostgreSQL Ranker Function `get_recommended_feed_v2`.
- **Mô tả:** Xếp hạng bài viết thông minh dựa trên 6 yếu tố trọng số:
  - Điểm quan hệ (Connection Score): Bạn bè (+32 điểm), Đang theo dõi (+24 điểm), Bài của bản thân (+8 điểm), Khám phá (+6 điểm).
  - Độ tương đồng sở thích (Topic Affinity): Phân tích hashtag và caption khớp với sở thích khai báo (+14 điểm).
  - Độ gắn kết tác giả (Author Affinity): Tính toán tương tác của người dùng với tác giả trong 90 ngày (Comment/Share trọng số 4, Like trọng số 2.5, Mở ảnh trọng số 1).
  - Chất lượng tương tác (Engagement Quality): Áp dụng hàm logarit `ln(1 + likes) * 3 + ln(1 + comments) * 5` để bài viral không áp đảo tuyến tính.
  - Tính mới (Recency Bonus): Ưu tiên bài viết mới đăng theo hàm suy giảm thời gian.
  - Giữ vị trí bài viết ổn định (No aggressive cooldown): Bài viết và avatar tác giả không bị biến mất bất ngờ khi người dùng lướt qua hoặc tải lại.

### 5.3 Băng chuyền "Những người bạn có thể biết" (People You May Know Carousel)
- **Widget:** `PeopleYouMayKnowCarousel`
- **Mô tả:** Xuất hiện xen kẽ tự nhiên giữa các bài viết trên Bảng tin.
- **Nghiệp vụ:** Gợi ý danh sách người dùng tiềm năng dựa trên số bạn chung (Mutual Friends Count) và số sở thích tương đồng (Shared Interests Count). Người dùng có thể nhấn "Kết bạn", "Theo dõi" hoặc bấm icon [X] để bỏ qua gợi ý.

### 5.4 Tạo bài viết mới (Create Post Screen)
- **Màn hình:** `CreatePostScreen` (`/create`)
- **Mô tả:** Màn hình soạn thảo bài viết phong phú đa tính năng.
- **Khả năng đính kèm:**
  - Nhập nội dung bài viết (hỗ trợ tự động nhận diện hashtag và mention).
  - Chọn nhiều ảnh từ thư viện hoặc chụp ảnh mới (hỗ trợ tối đa 10 ảnh/video).
  - Nén ảnh thông minh trước khi tải lên (`flutter_image_compress`).
  - Gắn thẻ cảm xúc (Feeling/Activity): Vui vẻ, hào hứng, thư giãn, đang đi du lịch,...
  - Gắn thẻ bạn bè (Tag Friends): Chọn từ danh sách bạn bè thân thiết.
  - Gắn thẻ địa điểm (Location Tagging).
  - Gắn nhạc nền bài viết (Music Track).

### 5.5 Soạn thảo & Gợi ý Caption bằng Trí tuệ nhân tạo (AI Caption Generator)
- **Tích hợp:** Google Gemini AI qua Edge Function `ai-service`.
- **Mô tả:** Khi người dùng bí ý tưởng viết caption, có thể nhấn nút "Gợi ý Caption bằng AI".
- **Nghiệp vụ:** Ứng dụng mã hóa ảnh đã chọn sang Base64 và gửi lên AI Service. Gemini Vision sẽ phân tích bối cảnh bức ảnh (ví dụ: bãi biển, quán cà phê, buổi tiệc) và gợi ý 3 phong cách caption phù hợp (Hài hước, Sâu lắng, Ngắn gọn bắt trend) kèm bộ hashtag thịnh hành.

### 5.6 Gắn thẻ vị trí & Đọc tọa độ EXIF ảnh (Location Tagging)
- **Màn hình:** `LocationPickerScreen`
- **Mô tả:** Đính kèm vị trí địa lý vào bài viết để người xem biết bài được đăng ở đâu.
- **Nghiệp vụ:**
  - Tự động quét thẻ EXIF của ảnh vừa chụp để lấy kinh độ/vĩ độ gốc của bức ảnh.
  - Nếu không có ảnh hoặc ảnh không có EXIF, sử dụng GPS thiết bị (`geolocator`).
  - Tìm kiếm địa điểm xung quanh qua `PlacesService` (OpenStreetMap / Nominatim) và hiển thị danh sách địa danh, quán ăn, thành phố để người dùng chọn.

### 5.7 Đính kèm nhạc nền bài viết (Post Music Track)
- **Mô tả:** Đính kèm bài hát từ iTunes vào bài viết. Khi người đọc xem bài viết trên Bảng tin, một thanh Mini Player hiển thị tên bài hát sẽ xuất hiện kèm hiệu ứng sóng nhạc và phát âm thanh tương ứng.

### 5.8 Đa định dạng bố cục trình chiếu ảnh (Image Carousel Layouts)
- **Widget:** `ImageCarousel`
- **Mô tả:** Khi bài viết có nhiều ảnh, ứng dụng hỗ trợ nhiều chế độ bố cục bắt mắt:
  - Băng chuyền cuộn ngang chuẩn (Carousel Slider với chấm chỉ số trang).
  - Lưới ảnh phong cách ghép khung (Grid Collage 2, 3, 4 ảnh).
  - Chế độ xem phóng to toàn màn hình (`photo_view`) hỗ trợ thu phóng bằng 2 ngón tay (Pinch-to-zoom).

### 5.9 Hỗ trợ bài viết dạng Video (Video Posts)
- **Widget:** `AppVideoPlayer`
- **Mô tả:** Cho phép người dùng đăng tải các video ngắn định dạng MP4/MOV.
- **Nghiệp vụ:** Tự động phát khi cuộn vào khung nhìn (Autoplay in viewport), hỗ trợ nút bật/tắt tiếng (Mute/Unmute), thanh tiến trình thời lượng và xem toàn màn hình.

### 5.10 Nhãn dán nội dung do AI tạo (AI-Generated Post Label)
- **Mô tả:** Tuân thủ tiêu chuẩn minh bạch nội dung số. Nếu bài viết hoặc hình ảnh được tạo bởi các công cụ AI (như Midjourney, Stable Diffusion, DALL-E, Gemini), tác giả hoặc hệ thống kiểm duyệt có thể gắn cờ `is_ai_generated = true`. Bài viết sẽ hiển thị nhãn huy hiệu "✨ Nội dung tạo bởi AI" để người đọc phân biệt.

### 5.11 Màn hình xem trước bài viết (Post Publish Preview Screen)
- **Màn hình:** `PostPublishPreviewScreen`
- **Mô tả:** Trước khi phát hành bài viết lên toàn mạng xã hội, người dùng được đưa qua màn hình xem trước để kiểm tra diện mạo bài đăng thực tế.
- **Nghiệp vụ:**
  - Chọn phạm vi hiển thị: Công khai (Public), Bạn bè (Friends), Riêng tư chỉ mình tôi (Only Me).
  - Tự động chạy quét kiểm duyệt nội dung an toàn trước khi bấm nút "Đăng bài" chính thức.

### 5.12 Tương tác Thích bài viết tối ưu hóa (Post Likes & Optimistic UI)
- **Mô tả:** Thả tim / Bỏ thích bài viết.
- **Cơ chế tối ưu:**
  - **Optimistic UI:** Đổi ngay màu trái tim đỏ và tăng/giảm số lượt thích trên giao diện trong 0ms trước khi gửi request mạng. Rollback nếu gặp lỗi mạng.
  - **Batch Fetching:** Toàn bộ danh sách bài viết trên Bảng tin và Profile nạp trạng thái thích cùng lúc bằng 1 truy vấn `.inFilter()` duy nhất, triệt tiêu 100% hiện tượng nhấp nháy UI và lỗi N+1 truy vấn.

### 5.13 Bình luận bài viết & Trả lời bình luận (Post Comments & Threaded Replies)
- **Màn hình:** `PostDetailScreen` (`/feed/post/:id`)
- **Mô tả:** Xem chi tiết bài viết và danh sách thảo luận.
- **Nghiệp vụ:**
  - Phân cấp bình luận: Hỗ trợ bình luận gốc (Parent Comment) và trả lời bình luận lồng nhau (Child Reply).
  - Tự động cập nhật số lượng bình luận `comments_count` tức thì qua trigger CSDL.
  - Ô nhập bình luận dính đáy màn hình (Bottom pinned input bar) hỗ trợ nút gửi nhanh, chèn emoji và gắn thẻ `@username`.

### 5.14 Thích bình luận (Comment Likes)
- **Mô tả:** Người dùng có thể bấm thích từng bình luận riêng lẻ. Số lượt thích bình luận được đồng bộ tức thời và hiển thị ngay cạnh nội dung bình luận.

### 5.15 Phân tích cú pháp văn bản thông minh (Parsed Caption Text)
- **Widget:** `ParsedCaptionText`
- **Mô tả:** Bộ phân tích văn bản chuyên sâu:
  - Nhận diện các thẻ `#hashtag` và tô màu nổi bật. Bấm vào hashtag sẽ mở tìm kiếm các bài viết cùng chủ đề.
  - Nhận diện lời nhắc `@username`. Bấm vào sẽ mở thẳng trang cá nhân của người được nhắc tên.
  - Nhận diện các đường link `https://...` và hỗ trợ mở trình duyệt ngoài an toàn qua `url_launcher`.

### 5.16 Chia sẻ bài viết (Share Post)
- **Mô tả:** Chia sẻ bài viết ra các nền tảng mạng xã hội khác (Zalo, Messenger, Facebook, Telegram, Sao chép liên kết) thông qua package `share_plus` và Deep Link `https://viora.social/post/:id`.

### 5.17 Thùng rác bài viết & Khôi phục (Post Trash Bin)
- **Màn hình:** `TrashScreen` (`/trash`)
- **Mô tả:** Cơ chế Xóa mềm (Soft Delete) giúp người dùng an tâm không sợ vô tình xóa mất bài viết kỷ niệm.
- **Nghiệp vụ:**
  - Khi người dùng xóa bài viết, bài viết được chuyển vào Thùng rác (`deleted_at = now()`).
  - Thời hạn lưu giữ: **30 ngày** kể từ ngày xóa. Màn hình Thùng rác hiển thị đồng hồ đếm ngược số ngày/giờ còn lại của từng bài viết.
  - Nút **"Khôi phục" (Restore):** Đưa bài viết trở lại Bảng tin và trang cá nhân nguyên vẹn (giữ nguyên lượt like, comment).
  - Nút **"Xóa vĩnh viễn" (Delete Permanently):** Xóa hoàn toàn bản ghi khỏi CSDL và tự động dọn dẹp file ảnh/video trên Supabase Storage.
  - Tự động hóa: Supabase Scheduled Cron Job / Edge Function `cleanup-trash` tự động quét và xóa sạch các bài viết trong thùng rác đã quá 30 ngày.

---

## 6. PHÂN HỆ 4: TIN NGẮN 24 GIỜ (STORIES 24H)

### 6.1 Tạo Story mới (Create Story Modal)
- **Widget:** `CreateStoryModal`
- **Mô tả:** Đăng tải khoảnh khắc ngắn tạm thời dạng hình ảnh hoặc video ngắn.
- **Nghiệp vụ:**
  - Tải file lên bucket Storage `stories`.
  - Tự động thiết lập thời gian hết hạn sau đúng 24 giờ: `expires_at = created_at + interval '24 hours'`.
  - Cho phép chèn văn bản ngắn, nhạc nền hoặc sticker lên Story.

### 6.2 Thanh Stories trên đầu Feed (Stories Bar)
- **Widget:** `StoriesBar`
- **Mô tả:** Thanh cuộn ngang hiển thị các avatar tròn của bạn bè có story mới.
- **Đặc điểm:**
  - Ô đầu tiên: Nút dấu `+` đại diện cho Story của chính mình để đăng nhanh.
  - Vòng viền Gradient rực rỡ báo hiệu story chưa xem.
  - Vòng viền xám mờ báo hiệu toàn bộ story của người đó đã được xem hết.

### 6.3 Trình xem Story toàn màn hình (Story Viewer Modal)
- **Widget:** `StoryViewerModal`
- **Mô tả:** Trình chiếu Story phong cách Instagram/Facebook toàn màn hình sống động.
- **Tính năng điều khiển:**
  - Tự động chuyển Story kế tiếp sau 5 giây (Auto-advance progress bar).
  - Chạm và giữ ngón tay vào màn hình để tạm dừng (Hold to pause).
  - Chạm mép trái để xem lại story trước, chạm mép phải để chuyển story tiếp theo.
  - Vuốt xuống dưới để đóng trình xem story mượt mà.

### 6.4 Thống kê người xem Story (Story Views & Viewers List)
- **Bảng CSDL:** `story_views`
- **Mô tả:** Khi một người dùng mở xem story, hệ thống tự động ghi nhận bản ghi xem.
- **Nghiệp vụ:** Chủ sở hữu Story có thể vuốt lên để xem danh sách chi tiết những ai đã xem story của mình và thời điểm xem. Người xem không phải là chủ sở hữu sẽ không thấy danh sách này.

### 6.5 Phản hồi Story bằng tin nhắn (Story Direct Reply)
- **Mô tả:** Thanh nhập tin nhắn nhanh ngay dưới đáy Story Viewer cho phép người xem gửi phản hồi hoặc biểu cảm cảm xúc (Emoji reactions). Nội dung phản hồi sẽ tự động được gửi thành một tin nhắn trực tiếp kèm ảnh trích dẫn Story vào phòng chat 1-1 của hai người.

---

## 7. PHÂN HỆ 5: NHẮN TIN THỜI GIAN THỰC & QUẢN LÝ NHÓM

### 7.1 Danh sách cuộc trò chuyện (Conversations Screen)
- **Màn hình:** `ConversationsScreen` (`/chat`)
- **Mô tả:** Trung tâm liên lạc của ứng dụng, hiển thị tất cả cuộc trò chuyện trực tiếp (1-1) và trò chuyện nhóm.
- **Thông tin hiển thị:** Avatar đối phương hoặc avatar nhóm, Tên cuộc trò chuyện, Nội dung tin nhắn cuối cùng (rút gọn), Thời gian gửi (`timeago`), và Huy hiệu màu xanh/đỏ đếm số tin nhắn chưa đọc.
- **Sắp xếp thông minh:** Các cuộc hội thoại được Ghim (Pinned) luôn nổi trên đầu, tiếp theo là các cuộc hội thoại có tin nhắn mới nhất.

### 7.2 Cử chỉ vuốt quản lý hội thoại (Slidable Gestures)
- Tích hợp `flutter_slidable` phong cách iOS:
  - **Vuốt từ Trái sang Phải:**
    - **Ghim / Bỏ ghim (Toggle Pin):** Cuộc trò chuyện được ghim sẽ đổi màu nền nhẹ nhàng, có icon ghim nhỏ và luôn cố định ở top đầu danh sách.
  - **Vuốt từ Phải sang Trái:**
    - **Ẩn cuộc trò chuyện (Hide):** Chuyển đoạn chat vào danh mục "Đoạn chat bị ẩn" để bảo vệ sự riêng tư.
    - **Xóa cuộc trò chuyện (Delete):** Hiển thị hộp thoại xác nhận phong cách Cupertino để xóa cuộc trò chuyện khỏi danh sách.

### 7.3 Đoạn chat bị ẩn & Mã khóa Passcode (Hidden Conversations)
- **Màn hình:** `HiddenConversationsScreen` (`/chat/hidden`)
- **Mô tả:** Tính năng bảo mật cao cấp giúp người dùng giấu các cuộc trò chuyện nhạy cảm.
- **Nghiệp vụ:**
  - Bắt buộc phải nhập đúng **Mã khóa PIN 6 chữ số** mới có thể mở màn hình này.
  - Hỗ trợ luồng: Thiết lập mã khóa lần đầu (`PasscodeMode.setup`) và Xác thực mã khóa (`PasscodeMode.verify`).
  - Bàn phím số phong cách iOS có hiệu ứng rung phản hồi và hoạt ảnh chấm tròn mật mã.

### 7.4 Khôi phục mã khóa đoạn chat ẩn (Passcode Recovery)
- **Edge Function:** `hidden-passcode-recovery`
- **Mô tả:** Nếu người dùng quên mã PIN đoạn chat ẩn, hệ thống cung cấp mã khôi phục dự phòng gửi về email đăng ký để đặt lại mã mới mà không làm mất tin nhắn.

### 7.5 Phòng trò chuyện thời gian thực (Chat Screen)
- **Màn hình:** `ChatScreen` (`/chat/:conversationId`)
- **Công nghệ:** Đăng ký Realtime Channel Supabase `messages:conversation_id=eq.{id}`.
- **Đặc điểm:** Tốc độ nhận tin nhắn tính bằng mili-giây, cuộn mượt mà phân trang từ dưới lên (Reverse Pagination), bong bóng chat thông minh phân biệt bên gửi (màu gradient primary) và bên nhận (màu xám sáng).

### 7.6 Trạng thái trực tuyến & Đang gõ (Presence & Typing Indicators)
- **Widget:** `ChatPresenceSubtitle`
- **Mô tả:** Hiển thị trạng thái ngay dưới tên người nhận trên thanh AppBar.
- **Trạng thái:**
  - "Đang hoạt động" (Chấm xanh online).
  - "Hoạt động X phút trước" nếu đang offline.
  - "Đang soạn tin..." kèm hoạt ảnh dấu 3 chấm nhấp nháy khi đối phương đang gõ bàn phím.

### 7.7 Trạng thái gửi & Đã xem (Message Receipts)
- **Trạng thái:**
  - `Sending`: Đồng hồ cát / Mờ (khi offline).
  - `Sent`: 1 dấu tick xám (đã lưu máy chủ).
  - `Delivered`: 2 dấu tick xám (đã tới thiết bị người nhận).
  - `Seen`: 2 dấu tick xanh kèm dòng chữ "✓✓ Đã xem lúc hh:mm" dưới tin nhắn cuối cùng khi người nhận mở phòng chat.

### 7.8 Soạn tin & Gợi ý nhắc tên thành viên (Chat Mention Suggestions)
- **Widget:** `ChatMentionSuggestions`
- **Mô tả:** Khi gõ ký tự `@` trong khung chat nhóm, một danh sách popover hiển thị danh sách thành viên trong nhóm kèm avatar và tên. Chọn thành viên sẽ tự động điền `@username` và kích hoạt thông báo riêng cho người đó.

### 7.9 Gửi ảnh kèm chú thích & Trình xem phóng to
- **Widget:** `FullScreenImageViewer`
- **Mô tả:** Người dùng có thể gửi ảnh chụp trực tiếp từ camera hoặc ảnh từ thư viện, đính kèm thêm dòng văn bản chú thích (caption) dưới ảnh. Nhấp vào ảnh trong phòng chat sẽ mở trình xem ảnh phóng to, hỗ trợ lưu ảnh về máy.

### 7.10 Tin nhắn thoại (Voice Messages)
- **Widget:** `VoiceRecorderBar` & `VoiceMessageBubble`
- **Mô tả:** Gửi tin nhắn bằng giọng nói trực tiếp.
- **Quy trình:**
  - Nhấn giữ hoặc vuốt khóa để ghi âm bằng micrô (`record` package).
  - Hiển thị thanh đo biên độ sóng âm thời gian thực (Waveform Visualizer) và đồng hồ đếm giây.
  - Hỗ trợ nút Hủy (thùng rác), nút Nghe thử lại trước khi gửi và nút Gửi.
  - Tải file âm thanh `.m4a` lên bucket `messages`.
  - Bong bóng tin nhắn thoại có nút Play/Pause, thanh tiến trình kéo tua được và hiển thị tổng thời lượng âm thanh.

### 7.11 Menu ngữ cảnh tin nhắn & Thả cảm xúc (Message Context Menu)
- **Widget:** `MessageContextMenuRoute` & `MessagePopupMenuContent`
- **Mô tả:** Nhấn giữ vào bất kỳ tin nhắn nào để mở menu tương tác nâng cao.
- **Hành động hỗ trợ:**
  - **Thả biểu cảm (Emoji Reactions):** Chọn nhanh các cảm xúc ❤️, 👍, 😂, 😮, 😢, 🙏. Biểu cảm gắn liền dưới bong bóng tin nhắn và cập nhật realtime cho cả hai bên.
  - **Trả lời (Reply / Quote):** Trích dẫn tin nhắn gốc kèm tên người gửi, nhấp vào tin nhắn trích dẫn sẽ tự động cuộn đến tin nhắn gốc.
  - **Sao chép (Copy text):** Sao chép nội dung tin nhắn vào clipboard.
  - **Chuyển tiếp (Forward):** Chuyển tiếp tin nhắn sang một người hoặc nhóm khác.
  - **Ghim tin nhắn (Pin message).**

### 7.12 Thu hồi tin nhắn hai chiều (Recall Message)
- **Mô tả:** Người gửi có thể bấm "Thu hồi tin nhắn" trong vòng thời gian quy định.
- **Nghiệp vụ:** Tin nhắn được cập nhật trạng thái `is_recalled = true`, nội dung chuyển thành *"Tin nhắn đã được thu hồi"* ở cả hai phía người gửi và người nhận, nội dung gốc bị xóa khỏi CSDL để bảo mật thông tin.

### 7.13 Ghim tin nhắn & Nhảy đến tin nhắn ghim (Pinned Messages)
- **Widget:** `ChatPinnedBanner`
- **Mô tả:** Cho phép ghim một hoặc nhiều tin nhắn quan trọng trong cuộc hội thoại lên đầu phòng chat.
- **Nghiệp vụ:** Nhấn vào thanh ghim tin nhắn sẽ mở "Cửa sổ tin nhắn" (Message Window) và tự động cuộn mượt mà (`ScrollablePositionedList`) đến chính xác vị trí tin nhắn đó trong lịch sử trò chuyện kèm hiệu ứng chớp sáng làm nổi bật.

### 7.14 Trò chuyện nhóm (Group Chats)
- **Widget:** `CreateGroupModal`
- **Mô tả:** Tạo nhóm chat nhiều người.
- **Nghiệp vụ:** Đặt tên nhóm, chọn ảnh đại diện nhóm, tìm kiếm và tick chọn nhiều người từ danh sách bạn bè để thêm vào nhóm cùng lúc.

### 7.15 Quản lý thành viên nhóm (Group Members Screen)
- **Màn hình:** `GroupMembersScreen` (`/chat/:conversationId/members`)
- **Mô tả:** Xem danh sách toàn bộ thành viên trong nhóm.
- **Phân cấp vai trò:**
  - **Trưởng nhóm (Owner):** Người tạo nhóm, có toàn quyền tối cao.
  - **Quản trị viên (Admin):** Được Trưởng nhóm bổ nhiệm để hỗ trợ quản lý.
  - **Thành viên (Member):** Người tham gia thông thường.

### 7.16 Phân quyền quản trị nhóm (Group Admin Screen)
- **Màn hình:** `GroupAdminScreen` (`/chat/:conversationId/manage`)
- **Mô tả:** Dành cho Trưởng nhóm và Quản trị viên tùy biến quy tắc nhóm.
- **Cấu hình quyền hạn:**
  - Quyền sửa thông tin nhóm (Tên, Ảnh): Mọi người hoặc Chỉ Admin.
  - Quyền gửi tin nhắn: Mọi người hoặc Chỉ Admin (chế độ nhóm thông báo).
  - Quyền thêm thành viên mới: Mọi người hoặc Chỉ Admin.
  - Phê duyệt thành viên mới (Membership Approval).
  - Bổ nhiệm / Bãi nhiệm chức vụ Quản trị viên.
  - Xóa thành viên khỏi nhóm (Kick member).
  - Cấm thành viên (Ban / Unban member): Thành viên bị cấm sẽ không thể được mời lại vào nhóm.
  - Giải tán nhóm (Dissolve Group - Chỉ dành cho Owner): Xóa vĩnh viễn nhóm và toàn bộ tin nhắn.

### 7.17 Tin nhắn hệ thống tự động (Chat System Messages)
- **Widget:** `ChatSystemMessage`
- **Mô tả:** Hiển thị tin nhắn thông báo dạng viên thuốc (pill) ở giữa màn hình khi có sự kiện nhóm diễn ra:
  - *"A đã tạo nhóm"*
  - *"A đã thêm B vào nhóm"*
  - *"B đã rời khỏi nhóm"*
  - *"A đã đổi tên nhóm thành X"*
  - *"A đã ghim một tin nhắn"*

### 7.18 Tùy biến hình nền phòng chat (Chat Wallpapers)
- **Màn hình:** `ConversationSettingsScreen` & `WallpaperHistoryScreen`
- **Mô tả:** Cho phép mỗi cuộc trò chuyện có một hình nền độc đáo riêng.
- **Nghiệp vụ:** Chọn từ kho hình nền nghệ thuật mặc định của ứng dụng (`assets/images/wallpapers/`) hoặc tải ảnh tùy chỉnh từ thiết bị. Lưu lại lịch sử hình nền đã từng sử dụng để người dùng chuyển đổi qua lại dễ dàng.

### 7.19 Kho phương tiện đã chia sẻ (Shared Media Screen)
- **Màn hình:** `SharedMediaScreen` (`/chat/:conversationId/media`)
- **Mô tả:** Nơi lưu trữ tập trung tất cả tài nguyên đã từng gửi trong phòng chat.
- **Gồm 3 Tab:**
  - **Hình ảnh & Video:** Lưới ảnh tất cả các hình ảnh/video đã gửi kèm ngày tháng.
  - **Liên kết (Links):** Danh sách các đường link web đã chia sẻ kèm tiêu đề xem trước.
  - **Tài liệu (Files):** Danh sách file âm thanh và tài liệu đính kèm.

---

## 8. PHÂN HỆ 6: CUỘC GỌI THOẠI & VIDEO CALL WEBRTC

> **Giải pháp kỹ thuật:** Sử dụng WebRTC chuẩn thông qua **LiveKit Cloud** kết hợp Supabase Edge Function `livekit-token` và Realtime Signal. Hoạt động đồng thời và thông suốt giữa **Web (Chrome/Safari) và Mobile (Android/iOS)**.

### 8.1 Khởi tạo cuộc gọi đi (Outgoing Call Screen)
- **Màn hình:** `OutgoingCallScreen` (`/call/outgoing`)
- **Mô tả:** Mở ra khi người dùng bấm nút Gọi điện (Voice Call) hoặc Gọi Video (Video Call) trong phòng chat.
- **Nghiệp vụ:**
  - Tạo bản ghi mới trong bảng `calls` với trạng thái `status = 'ringing'` và tên phòng `room_name` là một mã UUID duy nhất.
  - Gọi Edge Function `livekit-token` để sinh mã JWT Token xác thực cho người gọi.
  - Phát âm thanh chuông chờ máy (Dial tone) qua `CallAudioService`.
  - Bộ đếm thời gian 60 giây chờ đối phương bắt máy. Nếu quá 60s không ai nhấc máy, cuộc gọi tự động chuyển thành `missed` và đóng màn hình.
  - Nút Hủy cuộc gọi đỏ ở giữa để người gọi có thể gác máy bất cứ lúc nào (`status = 'cancelled'`).

### 8.2 Tiếp nhận cuộc gọi đến thời gian thực (Incoming Call Screen)
- **Màn hình:** `IncomingCallScreen` (`/call/incoming`)
- **Mô tả:** Hiển thị đè toàn màn hình khi có cuộc gọi tới, bất kể người dùng đang đứng ở bất kỳ màn hình nào trong ứng dụng.
- **Nghiệp vụ:**
  - Lắng nghe sự kiện qua Supabase Realtime tại `rootNavigatorKey` / `app.dart`.
  - Phát nhạc chuông điện thoại (Ringtone) liên tục.
  - Hiển thị Avatar lớn, Tên người gọi, loại cuộc gọi (Thoại hay Video).
  - Nút **Từ chối (Decline):** Cập nhật `status = 'declined'`, ngắt chuông và đóng màn hình.
  - Nút **Nhấc máy (Accept):** Cập nhật `status = 'accepted'`, ngắt nhạc chuông, xin token LiveKit và chuyển ngay sang màn hình `ActiveCallScreen`.

### 8.3 Màn hình trong cuộc gọi trực tiếp (Active Call Screen)
- **Màn hình:** `ActiveCallScreen` (`/call/active`)
- **Mô tả:** Phòng giao tiếp âm thanh / hình ảnh thời gian thực chất lượng cao.
- **Tính năng điều khiển:**
  - **Khung hình Video:** Hiển thị video đối phương tràn màn hình, video bản thân ở góc nhỏ dạng Picture-in-Picture (PiP).
  - **Bật / Tắt Micrô (Mute/Unmute):** Điều khiển track âm thanh cục bộ.
  - **Bật / Tắt Camera:** Điều khiển track video cục bộ.
  - **Đổi Camera (Flip Camera):** Chuyển đổi giữa camera trước và camera sau (trên thiết bị di động).
  - **Bật Loa ngoài (Speakerphone):** Điều hướng âm thanh ra loa ngoài hoặc tai nghe thoại.
  - **Đồng hồ cuộc gọi:** Đếm thời lượng cuộc gọi trực tiếp theo giây (`00:00`).

### 8.4 Kết thúc cuộc gọi & Lưu nhật ký
- **Mô tả:** Khi một trong hai bên bấm nút Kết thúc (gác máy):
  - Ngắt kết nối phòng LiveKit (`room.disconnect()`).
  - Cập nhật bản ghi bảng `calls`: `status = 'ended'`, `ended_at = now()`, tự động tính toán tổng thời lượng cuộc gọi `duration_sec`.
  - Tự động ghi một tin nhắn thông báo vào phòng chat: *"Cuộc gọi thoại (03:45)"* hoặc *"Cuộc gọi nhỡ"*.

---

## 9. PHÂN HỆ 7: TÌM KIẾM, KHÁM PHÁ & TRÍ TUỆ NHÂN TẠO

### 9.1 Tìm kiếm người dùng nhanh (Search User Screen)
- **Màn hình:** `SearchScreen` (`/search`)
- **Mô tả:** Tìm kiếm bạn bè và người dùng trong toàn hệ thống.
- **Nghiệp vụ:**
  - Tự động Focus vào ô tìm kiếm khi mở màn hình.
  - Cơ chế **Debounce 400ms:** Chờ người dùng ngừng gõ phím 400ms mới phát lệnh truy vấn, tránh spam quá tải máy chủ.
  - Truy vấn tìm kiếm không phân biệt chữ hoa/thường (`ILIKE`) theo cả `username` và `full_name`.
  - Kết quả hiển thị: Avatar, Tên đầy đủ, Username và nút Theo dõi/Bỏ theo dõi nhanh.

### 9.2 Lưu lịch sử tìm kiếm cục bộ (Search History)
- **Cơ sở dữ liệu:** Lưu trong Isar DB (`IsarSearchHistory`) trên Mobile và Hive trên Web.
- **Nghiệp vụ:** Hiển thị danh sách các từ khóa vừa tìm kiếm gần đây khi người dùng mở ô tìm kiếm. Cho phép bấm vào từ khóa để tìm lại, xóa từng từ khóa hoặc bấm nút "Xóa tất cả lịch sử".

### 9.3 Tìm kiếm thông minh kết hợp AI (AI Hybrid Search)
- **Backend:** Edge Function `ai-service` kết hợp PostgreSQL pgvector.
- **Mô tả:** Tìm kiếm ngữ nghĩa bài viết và nội dung dựa trên công nghệ **Reciprocal Rank Fusion (RRF)**.
- **Nghiệp vụ:** Người dùng không chỉ tìm kiếm theo từ khóa chính xác mà có thể tìm theo ý nghĩa (ví dụ: gõ "quán ăn ngon ngắm hoàng hôn" sẽ tìm ra các bài viết có ảnh hoặc caption liên quan đến ẩm thực chiều tà dù không chứa chính xác các từ đó).

### 9.4 Khám phá bài viết ngoài mạng lưới (Discovery Pool)
- **Mô tả:** Thuật toán đề xuất tự động đưa vào Bảng tin các bài viết thịnh hành công khai từ những tác giả mà người dùng chưa theo dõi, giúp mở rộng thế giới quan và tăng khả năng kết nối bạn bè mới.

---

## 10. PHÂN HỆ 8: THÔNG BÁO THỜI GIAN THỰC & HUY HIỆU

### 10.1 Lắng nghe thông báo Realtime
- **Màn hình:** `NotificationScreen` (`/notifications`)
- **Mô tả:** Cập nhật mọi tương tác liên quan đến tài khoản ngay khi có sự kiện phát sinh mà không cần tải lại trang.

### 10.2 Phân loại thông báo chi tiết
Hệ thống phân loại và hiển thị icon, nội dung tương ứng theo từng loại:
- `like`: *"{User} đã thích bài viết của bạn"* (Icon tim hồng).
- `comment`: *"{User} đã bình luận: {nội dung}"* (Icon bong bóng chat xanh).
- `comment_like`: *"{User} đã thích bình luận của bạn"* (Icon tim nhỏ).
- `follow`: *"{User} đã bắt đầu theo dõi bạn"* (Icon người dùng xanh dương kèm nút Theo dõi lại).
- `friend_request`: *"{User} đã gửi cho bạn lời mời kết bạn"* (Kèm nút Chấp nhận/Từ chối).
- `friend_accept`: *"{User} đã chấp nhận lời mời kết bạn của bạn"*.
- `mention`: *"{User} đã nhắc đến bạn trong một bài viết/bình luận"*.
- `group_added`: *"{User} đã thêm bạn vào nhóm {GroupName}"*.
- `group_dissolved`: *"Nhóm {GroupName} đã bị giải tán bởi trưởng nhóm"*.
- `moderation_warning`: Cảnh báo vi phạm tiêu chuẩn cộng đồng từ ban quản trị.
- `moderation_action`: Thông báo hành động xử lý bài viết vi phạm.

### 10.3 Huy hiệu số lượng chưa đọc (Badges)
- Tự động đếm số thông báo chưa đọc (`is_read = false`) và số tin nhắn chưa đọc từ CSDL.
- Hiển thị chấm đỏ nổi bật trên icon Chuông thông báo và icon Tin nhắn ở thanh TabBar dưới đáy màn hình. Số đếm đồng bộ tức thời chéo giữa tất cả các màn hình.

### 10.4 Đánh dấu đã đọc & Điều hướng tương tác thông minh
- Khi người dùng mở màn hình Thông báo, hệ thống tự động cập nhật trạng thái đã đọc.
- Bấm vào từng dòng thông báo sẽ điều hướng chính xác đến đối tượng tương ứng: Bấm thông báo like/comment -> Nhảy đến bài viết chi tiết; Bấm thông báo follow -> Mở trang cá nhân người đó; Bấm thông báo nhóm -> Mở phòng chat nhóm; Bấm thông báo kiểm duyệt -> Mở màn hình giải trình vi phạm.

---

## 11. PHÂN HỆ 9: AN TOÀN CỘNG ĐỒNG, KIỂM DUYỆT & KHIẾU NẠI

### 11.1 Báo cáo vi phạm đa cấp độ (Report Bottom Sheet)
- **Widget:** `ReportBottomSheet`
- **Mô tả:** Cho phép người dùng báo cáo bất kỳ bài viết, bình luận, tin nhắn hoặc tài khoản người dùng nào có dấu hiệu vi phạm.
- **Danh mục báo cáo phân cấp:**
  - Spam / Tin nhắn rác.
  - Quấy rối, đe dọa hoặc bắt nạt.
  - Bạo lực, máu me hoặc nội dung nguy hiểm.
  - Khỏa thân, khiêu dâm hoặc tình dục.
  - Phát ngôn thù ghét, phân biệt đối xử.
  - Thông tin sai sự thật, lừa đảo.
- **Nghiệp vụ kèm theo:** Người báo cáo có thể tick chọn đồng thời: "Chặn người dùng này", "Ẩn nội dung này khỏi bảng tin của tôi".
- **Kích hoạt tự động:** Gửi dữ liệu vào bảng `reports` và tự động kích hoạt Edge Function `process-report` tính toán điểm ưu tiên xử lý trong nền.

### 11.2 Đường ống kiểm duyệt AI 6 giai đoạn (6-Stage AI Moderation Pipeline)
- **Tích hợp:** Edge Function `moderate-content` và `ai-service` chạy mô hình Gemini AI.
- **Các cấp độ quyết định:**
  - `ALLOW`: Nội dung trong sạch, cho phép xuất bản công khai bình thường.
  - `FLAG_WARNING`: Nội dung mấp mé tiêu chuẩn, gửi cảnh báo nhắc nhở tác giả.
  - `SHADOW_LIMIT`: Hạn chế phân phối, chỉ hiển thị sau lớp cảnh báo che mờ.
  - `UNDER_REVIEW`: Tạm ẩn để chuyển hàng đợi kiểm duyệt viên con người xem xét.
  - `REMOVE`: Vi phạm nghiêm trọng (khiêu dâm, bạo lực cực đoan), tự động gỡ bài tức thì.

### 11.3 Cảnh báo nội dung nhạy cảm & Lớp phủ che mờ (Restricted Content Reveal)
- **Widget:** `RestrictedContentReveal`
- **Mô tả:** Đối với các nội dung bị đánh nhãn `shadow_limited`:
  - Bài viết không hiển thị ảnh/chữ trực tiếp mà bị phủ một lớp kính mờ màu xám kèm icon con mắt gạch chéo.
  - Hiển thị dòng cảnh báo: *"Nội dung này có thể chứa hình ảnh nhạy cảm hoặc vi phạm tiêu chuẩn cộng đồng."*
  - Người dùng có toàn quyền bấm nút "Xem nội dung" nếu vẫn muốn tiếp tục xem.

### 11.4 Chi tiết thông báo xử phạt (Moderation Notification Detail Screen)
- **Màn hình:** `ModerationNotificationDetailScreen` (`/notifications/moderation/:id`)
- **Mô tả:** Khi tác giả bị xử lý bài viết, màn hình này giải thích minh bạch lý do: Bài viết vi phạm điều khoản nào, mức độ điểm rủi ro (Risk Score), hình thức áp dụng và hướng dẫn khắc phục.

### 11.5 Hệ thống điểm phạt (Violations & Strike System)
- **Bảng CSDL:** `user_violations`
- **Mô tả:** Tích lũy số lần vi phạm (Strikes) của từng tài khoản:
  - 1 Strike: Cảnh cáo trong ứng dụng.
  - 2 Strikes: Tạm khóa tính năng đăng bài và bình luận trong 24 giờ.
  - 3 Strikes: Khóa tính năng nhắn tin trong 7 ngày.
  - Trên 3 Strikes: Khóa tài khoản tạm thời hoặc vĩnh viễn tùy theo quyết định của Admin.

### 11.6 Gửi đơn khiếu nại / Kháng cáo (Appeals Screen)
- **Màn hình:** `AppealsScreen`
- **Mô tả:** Đảm bảo tính công bằng. Nếu người dùng cho rằng quyết định của AI hoặc kiểm duyệt viên là nhầm lẫn:
  - Người dùng có thể viết đơn giải trình lý do kháng cáo kèm bằng chứng.
  - Trạng thái đơn được cập nhật rõ ràng: Đang chờ duyệt (Pending), Đã chấp nhận (Approved - tự động gỡ strike), Bị từ chối (Rejected).

### 11.7 Phân quyền Quản trị viên (Admin Management)
- **Hệ thống RPC & Edge Function:** `admin-user-management`
- **Chức năng:** Dành cho quản trị viên hệ thống để tra cứu danh sách báo cáo, duyệt đơn kháng cáo, khóa/mở khóa tài khoản người dùng và xem logs hoạt động kiểm duyệt.

---

## 12. PHÂN HỆ 10: KIẾN TRÚC NGOẠI TUYẾN & ĐỒNG BỘ DỮ LIỆU

```
  ┌────────────────────────────────────────────────────────┐
  │                    FLUTTER UI LAYER                    │
  └───────────────────────────▲────────────────────────────┘
                              │ Reactive Streams (watch)
  ┌───────────────────────────┴────────────────────────────┐
  │         REPOSITORY LAYER (Single Source of Truth)      │
  └─────────────┬────────────────────────────▲─────────────┘
                │ writeTxn                   │
  ┌─────────────▼─────────────┐ ┌────────────┴─────────────┐
  │       ISAR DATABASE       │ │       SYNC ENGINE        │
  │   (Local Offline Store)   │ │  (Outbox & Delta Sync)   │
  │ ───────────────────────── │ └────────────▲─────────────┘
  │ - IsarMessage             │              │ Push / Pull
  │ - IsarConversation        │              │
  │ - IsarPost / IsarProfile  │ ┌────────────▼─────────────┐
  │ - IsarSyncQueue           │ │    SUPABASE BACKEND      │
  └───────────────────────────┘ └──────────────────────────┘
```

### 12.1 Cơ sở dữ liệu cục bộ Isar DB & IndexedDB Hive
- **Mobile (Android/iOS):** Sử dụng **Isar Database v3** lưu trữ dạng nhị phân siêu tốc trực tiếp trên bộ nhớ máy, hỗ trợ ACID transactions và reactive queries.
- **Web (Trình duyệt):** Sử dụng **Hive** lưu trữ vào **IndexedDB** của trình duyệt, đảm bảo app chạy mượt trên web mà không bị lỗi tương thích native C++.
- **Các Collections được lưu trữ:**
  - `IsarMessage`: Tin nhắn chat offline.
  - `IsarConversation`: Danh sách phòng chat, trạng thái ghim/ẩn.
  - `IsarPost`: Cache các bài viết trên Bảng tin.
  - `IsarProfile`: Cache thông tin trang cá nhân.
  - `IsarNotification`: Cache danh sách thông báo.
  - `IsarSearchHistory`: Lịch sử từ khóa tìm kiếm.
  - `IsarPostDraft`: Lưu nháp bài viết đang soạn dở.
  - `IsarSyncQueue`: Hàng đợi các lệnh cần đồng bộ.

### 12.2 Mô hình Outbox Pattern & Hàng đợi đồng bộ (IsarSyncQueue)
- Khi người dùng thực hiện thao tác trong lúc mất mạng (Gửi tin nhắn, Thích bài viết, Đăng bài, Đánh dấu đã xem):
  - Dữ liệu lập tức hiển thị ngay trên màn hình (Optimistic UI).
  - Bản ghi được lưu ngay vào Isar Database nội bộ.
  - Một tác vụ mutation tương ứng được đưa vào hàng đợi `IsarSyncQueue` kèm payload JSON và số lần thử lại (retry count).

### 12.3 Động cơ đồng bộ hai chiều (Sync Engine & Delta Sync)
- **Service:** `sync_engine.dart`
- **Nghiệp vụ:**
  - **Lắng nghe mạng:** Giám sát liên tục trạng thái kết nối mạng qua `ConnectivityService`.
  - **Push (Đẩy dữ liệu lên):** Ngay khi có mạng trở lại, Sync Engine tự động duyệt hàng đợi `IsarSyncQueue` theo thứ tự thời gian FIFO, gọi API Supabase tương ứng để hoàn tất ghi nhận, nhận ID máy chủ thực sự và xóa item khỏi hàng đợi.
  - **Pull (Kéo dữ liệu mới - Delta Sync):** Đọc mốc thời gian `last_synced_at` từ cài đặt, chỉ tải các bản ghi có `updated_at > last_synced_at` từ Supabase về ghi đè vào Isar DB, giúp tiết kiệm 95% băng thông và tăng tốc tải trang.

### 12.4 Quản lý bộ nhớ đệm đa phương tiện (Media Cache Manager)
- **Service:** `media_cache_manager.dart`
- **Mô tả:**
  - Sử dụng `flutter_cache_manager` cache các tệp tin hình ảnh, video và tin nhắn thoại vào bộ nhớ đĩa cục bộ. Khi người dùng xem lại ảnh hoặc nghe lại voice lúc mất mạng, app sẽ đọc trực tiếp từ file cache mà không cần kết nối internet.
  - Cơ chế tự động dọn dẹp (Cache Retention): Giới hạn dung lượng tối đa (ví dụ 500MB). Khi vượt ngưỡng, hệ thống tự động xóa bớt các file phương tiện cũ nhất (LRU - Least Recently Used).

---

## 13. PHÂN HỆ 11: CÀI ĐẶT HỆ THỐNG, ĐA NGÔN NGỮ & GIAO DIỆN

### 13.1 Giao diện phân nhóm phong cách iOS (Cupertino Grouped Settings)
- **Màn hình:** `SettingsScreen` (`/settings`)
- **Mô tả:** Thiết kế theo quy chuẩn giao diện của Apple iOS với các nhóm thẻ bo góc mềm mại, chia theo danh mục: **Truy cập**, **Tùy chỉnh**, **Hỗ trợ**, **Đăng xuất**.

### 13.2 Biểu ngữ tài khoản phong cách Apple ID (Profile Banner)
- Hiển thị nổi bật ở đầu trang Settings với Avatar cỡ lớn, Tên người dùng, dòng chữ chú thích *"Tài khoản, Bảo mật & Dữ liệu"* và nút icon mở nhanh Mã QR cá nhân. Bấm vào banner sẽ dẫn đến màn hình cấu hình chi tiết `AccountSettingsScreen`.

### 13.3 Thanh điều hướng kính mờ (Frosted-Glass Navigation Bar)
- **Widget:** `_IosTabBar`
- **Công nghệ:** Sử dụng `BackdropFilter` với độ mờ `ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10)` kết hợp hòa trộn màu sắc HSL Alpha Blending.
- **Hiệu ứng viên thuốc trượt (Sliding Active Pill):** Một hình elip phát sáng nhẹ sẽ trượt qua trượt lại mượt mà theo cử chỉ chuyển đổi giữa các tab.
- **Tự động thu gọn (Compact Mode):** Khi người dùng cuộn xem bài viết trên feed, thanh TabBar tự động thu nhỏ lại để tăng diện tích hiển thị nội dung. Khi cuộn ngược lên hoặc chạm nhẹ, thanh TabBar sẽ bung rộng trở lại trạng thái ban đầu.

### 13.4 Duy trì trạng thái chuyển Tab (StatefulShellRoute)
- Sử dụng `StatefulShellRoute.indexedStack` của GoRouter để điều hướng 5 Tab chính:
  1. Tab 1: **Bảng tin** (Feed)
  2. Tab 2: **Tin nhắn** (Chat)
  3. Nút giữa: **Đăng bài** (Create Post)
  4. Tab 3: **Thông báo** (Notifications)
  5. Tab 4: **Cài đặt** (Settings)
- Mỗi Tab sở hữu một Navigator Stack riêng biệt, giúp giữ nguyên vị trí cuộn và trạng thái form nhập liệu khi người dùng chuyển qua lại giữa các Tab.

### 13.5 Chế độ Giao diện Sáng / Tối (Light & Dark Theme)
- Chuyển đổi linh hoạt thông qua công tắc gạt `CupertinoSwitch` trong Settings.
- Hệ màu được tối ưu tương phản cao: Màu nền Dark Mode sâu thẳm (`#0A0B0E`), không gây mỏi mắt trong bóng tối; Màu Light Mode thanh lịch, tinh tế.
- Trạng thái giao diện được ghi nhớ bền vững qua SharedPreferences.

### 13.6 Hỗ trợ Đa ngôn ngữ (Localization)
- **Màn hình:** `LanguageSettingsScreen` (`/settings/language`)
- **Hỗ trợ:** **Tiếng Việt 🇻🇳** và **English 🇬🇧** (`AppTranslations`).
- **Nghiệp vụ:** Chuyển đổi ngôn ngữ tức thời trên toàn bộ ứng dụng mà không cần khởi động lại. Cập nhật toàn bộ các nhãn, thông báo, nút bấm và định dạng ngày giờ.

### 13.7 Hệ thống thông báo nổi (Toast & In-app Feedback)
- **Service:** `ToastService` & `AppToast`
- **Mô tả:** Hiển thị thông báo nổi phong cách iOS Dynamic Island ở phía trên màn hình cho các hành động thành công, cảnh báo hoặc lỗi. Tự động biến mất sau 3 giây hoặc vuốt lên để gạt bỏ.

### 13.8 Giám sát lỗi hệ thống toàn cục (Global Error Handling & Sentry)
- Bắt tất cả lỗi ngoại lệ không lường trước (Uncaught Exceptions) trong quá trình người dùng sử dụng.
- Tự động ghi log lỗi, thông tin thiết bị và gửi về hệ thống giám sát **Sentry Flutter** để đội ngũ kỹ thuật phát hiện và xử lý lỗi kịp thời.

### 13.9 Caching hiệu năng cao & Giới hạn tần suất (Upstash Redis)
- **Service:** `UpstashRedisService`
- **Ứng dụng:**
  - **Rate Limiting:** Giới hạn số lượng request tạo bài viết, gửi tin nhắn, gửi mã OTP để phòng chống tấn công brute-force hoặc spam bot.
  - **Active Presence:** Theo dõi trạng thái hoạt động online của người dùng theo thời gian thực với độ trễ siêu thấp.

---

## 14. TỔNG KẾT TÀI NGUYÊN & KIẾN TRÚC BACKEND SUPABASE

### 14.1 Danh sách Supabase Edge Functions (Backend Services)

| Tên Edge Function | Vai trò & Trách nhiệm chính |
|:---|:---|
| `livekit-token` | Xác thực người dùng và cấp phát WebRTC Access Token cho phòng gọi LiveKit |
| `recommendation-engine` | Thuật toán gợi ý bảng tin (Feed v2) và gợi ý bạn bè (PYMK v2) |
| `ai-service` | Tích hợp Google Gemini: Tạo caption ảnh, quét kiểm duyệt nội dung, tìm kiếm ngữ nghĩa RRF |
| `moderate-content` | Đường ống kiểm duyệt bài viết tự động khi có bài đăng mới |
| `process-report` | Tiếp nhận và chấm điểm ưu tiên xử lý cho các báo cáo vi phạm |
| `admin-user-management`| API bảo mật dành riêng cho quản trị viên quản lý user, khóa tài khoản |
| `itunes-service` | Tìm kiếm bài hát và lấy đoạn nghe thử 30s từ Apple iTunes Search API |
| `places-service` | Tìm kiếm địa danh, định vị địa lý gắn thẻ bài viết qua OpenStreetMap |
| `translate-service` | Dịch thuật tự động bài viết và bình luận giữa Tiếng Việt và Tiếng Anh |
| `cleanup-trash` | Tác vụ định kỳ (Cron Job) dọn sạch bài viết trong thùng rác đã quá 30 ngày |
| `hidden-passcode-recovery` | Gửi mã khôi phục và xử lý đặt lại mã PIN cho đoạn chat bị ẩn |

### 14.2 Danh sách bảng CSDL PostgreSQL chính (Database Schema)

| Tên Bảng | Mô tả dữ liệu lưu trữ |
|:---|:---|
| `profiles` | Hồ sơ người dùng: avatar, cover, tên, username, bio, stats, cài đặt riêng tư |
| `posts` | Bài viết: tác giả, caption, số like, số comment, quyền riêng tư, trạng thái kiểm duyệt, thùng rác |
| `post_media` | Danh sách ảnh và video đính kèm trong bài viết kèm thứ tự sắp xếp |
| `post_likes` | Bản ghi lượt thích bài viết (tối ưu hóa batch-fetching) |
| `comments` | Bình luận bài viết và các câu trả lời lồng nhau |
| `comment_likes` | Lượt thích cho từng bình luận riêng lẻ |
| `stories` | Tin ngắn 24 giờ kèm thời hạn tự hủy `expires_at` |
| `story_views` | Nhật ký những người đã xem story |
| `conversations` | Danh sách phòng chat 1-1 và phòng chat nhóm |
| `conversation_members` | Danh sách thành viên trong nhóm, vai trò (Owner, Admin, Member), quyền hạn |
| `messages` | Tin nhắn: văn bản, ảnh, voice, tin nhắn hệ thống, trạng thái thu hồi, ghim, seen |
| `message_reactions`| Các biểu cảm cảm xúc (emoji) thả vào tin nhắn |
| `pinned_messages` | Danh sách các tin nhắn được ghim trong phòng chat |
| `calls` | Nhật ký cuộc gọi: caller, callee, room_name, loại thoại/video, trạng thái, thời lượng |
| `follows` | Quan hệ theo dõi giữa các người dùng |
| `friends` | Quan hệ bạn bè 2 chiều (lời mời kết bạn, đã chấp nhận) |
| `blocks` | Danh sách chặn người dùng 2 chiều |
| `notifications` | Thông báo thời gian thực gửi đến người dùng |
| `reports` | Các báo cáo vi phạm tiêu chuẩn cộng đồng |
| `user_violations` | Nhật ký vi phạm và điểm phạt (Strikes) của tài khoản |
| `appeals` | Đơn khiếu nại / kháng cáo của người dùng |
| `recommendation_events`| Nhật ký tương tác (view, dwell, click, like) phục vụ máy học gợi ý |
| `recommendation_dismissals`| Danh sách các bài viết / tài khoản mà người dùng bấm không quan tâm |

---

## 15. KẾT LUẬN & ĐÁNH GIÁ DỰ ÁN

Dự án **Viora (MiniSocial)** là một sản phẩm mạng xã hội hoàn chỉnh, hiện đại và có độ phức tạp cao, thể hiện năng lực kiến trúc phần mềm vững chắc:
1. **Kiến trúc hoàn thiện:** Phân tách rõ ràng giữa UI Presentation, Riverpod Providers, Repositories, Offline-First Engine và Supabase Backend.
2. **Khả năng đa nền tảng thực thụ:** Hoạt động đồng thời trên cả **Android, iOS và Web (Chrome/Edge/Safari)**, xử lý mượt mà các bài toán khó như WebRTC Call chéo nền tảng và Local Storage kép (Isar native trên mobile, Hive trên web).
3. **Trải nghiệm người dùng tinh tế:** Ngôn ngữ thiết kế Apple iOS Cupertino cao cấp, hiệu ứng kính mờ Frosted Glass, cử chỉ vuốt Slidable thông minh, Optimistic UI không có độ trễ.
4. **Tính năng tiên tiến:** Đã tích hợp các công nghệ thời thượng như **Trí tuệ nhân tạo Gemini AI**, **Thuật toán gợi ý cá nhân hóa Recommendation v2**, **Bảo mật 2FA MFA**, **Đoạn chat ẩn có mã PIN**, và **Gọi điện thoại / Video Call LiveKit**.

---
*Tài liệu được tổng hợp và đối soát tự động từ toàn bộ mã nguồn `lib/`, các tệp cấu hình `pubspec.yaml`, `supabase/migrations/` và các tài liệu đặc tả của dự án Viora.*
