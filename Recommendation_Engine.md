# Kế hoạch nâng cấp Thuật toán Đề xuất Bài viết (Recommendation Engine) chuẩn Social Apps

Tài liệu này phân tích cách các mạng xã hội lớn (**TikTok**, **Instagram**, **Facebook**, **X/Twitter**) xây dựng hệ thống đề xuất (Feed Recommendation Engine) và đề xuất phương án nâng cấp cho **MiniSocial**.

---

## 1. Nghiên cứu cách các ứng dụng Social hàng đầu đề xuất bài viết

| Nền tảng | Kiến trúc cốt lõi | Các chỉ số đánh giá quan trọng (Signal Scoring) |
| :--- | :--- | :--- |
| **TikTok** | 2-Stage Pipeline (Retrieval + Heavy Ranking) | **Implicit Signal (Tín hiệu ngầm)**: Dwell Time (thời gian xem), Re-watch, Image Click. Trọng số Dwell Time > Like. |
| **Facebook** | EdgeRank & Monolith Neural Ranker | **Affinity (Mối quan hệ)** $\times$ **Weight (Trọng số tương tác)** $\times$ **Decay (Suy giảm thời gian)**. Share/Comment có trọng số lớn hơn Like. |
| **Instagram** | Discovery Engine (In-network + Out-of-network) | **Interleaving (Trộn nội dung)**: 60-70% Bài viết từ Bạn bè/Following + 30-40% Bài viết gợi ý xu hướng dựa trên Topic/Hashtag. |
| **X (Twitter)**| Heavy Rank & Diversity Filter | **Author Diversity**: Lọc chống trùng lặp (không xuất hiện >2 bài liên tiếp của cùng 1 người) và Gravity Recency Decay. |

---

## 2. Phân tích hiện trạng của MiniSocial & Các điểm cần nâng cấp

### 🛑 Hạn chế hiện tại:
1. **Chưa khai thác dữ liệu tương tác ẩn (Implicit Feedback)**: Bảng `user_interactions` đã ghi nhận `view_dwell` (thời gian dừng chân) và `image_click`, nhưng hàm xếp hạng SQL trước đây chỉ tính `likes_count` và `comments_count`.
2. **Chưa có thuật toán Lọc đa dạng tác giả (Author Diversity Filter)**: Bài viết từ cùng 1 tác giả dễ bị xếp liền kề nhau gây nhàm chán.
3. **Chưa kết nối Sở thích cá nhân (Interest / Topic Matching)**: Người dùng khai báo `interests` (sở thích) trong hồ sơ chưa được match tự động với `#hashtags` bài viết.

---

## 3. Đề xuất Phương án Nâng cấp cho MiniSocial

### 🚀 3.1. Nâng cấp Công thức Xếp hạng Đa tầng (Multi-Factor Scoring)
$$Score = \text{ConnectionScore} + \text{EngagementScore} + \text{ImplicitScore} + \text{TopicScore} + \text{RecencyDecay}$$

1. **ConnectionScore (Mối quan hệ)**:
   - Bạn bè thân thiết / Kết bạn kép: **+40.0**
   - Đang theo dõi (Following): **+30.0**
   - Bài viết công khai / Khám phá: **+10.0**
   - Bài viết của chính mình: **+15.0** (nằm tự nhiên trên feed, không đẩy đè bạn bè)

2. **EngagementScore (Tương tác chủ động)**:
   - Bình luận (Comment): **+3.5**
   - Yêu thích (Like): **+2.0**

3. **ImplicitScore (Tín hiệu hành vi ngầm)**:
   - Xem ngâm bài viết (`view_dwell` > 2 giây): **+0.5** / giây (tối đa +5.0)
   - Bấm phóng to ảnh (`image_click`): **+2.0**

4. **TopicScore (Sự trùng khớp sở thích & Hashtag)**:
   - Nếu `#hashtag` hoặc từ khóa trong bài khớp với `interests` của user: **+15.0**

5. **RecencyDecay (Suy giảm Gravity Decay)**:
   - $\text{Decay} = \frac{120.0}{(T_{\text{hours}} + 2.0)^{1.4}}$ (Bài mới xuất hiện nổi bật hơn nhưng bài chất lượng cũ vẫn có cơ hội xuất hiện).

---

### 🚀 3.2. Thuật toán Lọc Đa dạng Tác giả (Author Diversity & Interleaver)
- Khi sắp xếp xong danh sách bài viết đề xuất, áp dụng bộ lọc **Author Diversity**:
  - Không xếp quá **2 bài viết liên tiếp** của cùng 1 tác giả.
  - Xen kẽ giữa bài viết của Bạn bè/Following với các bài viết Khám phá/Xu hướng theo tỷ lệ 7:3.

---

## 4. Các tệp tin sẽ thay đổi

### [Database & SQL Function]
#### [MODIFY] [20260725000004_merge_friends_followers_privacy.sql](file:///c:/cross_platform/mini_social/supabase/migrations/20260725000004_merge_friends_followers_privacy.sql)
- Cập nhật hàm RPC `get_recommended_feed` tính thêm điểm tương tác ngầm từ `user_interactions` và trùng khớp `interests`.

### [Edge Function & Data Repositories]
#### [MODIFY] [index.ts](file:///c:/cross_platform/mini_social/supabase/functions/recommendation-engine/index.ts)
- Bổ sung logic tính toán tín hiệu implicit feedback trong Edge Function.

#### [MODIFY] [recommendation_repository.dart](file:///c:/cross_platform/mini_social/lib/features/social/data/recommendation_repository.dart)
- Áp dụng bộ lọc **Author Diversity Interleaver** trên ứng dụng Flutter trước khi render danh sách lên UI Feed.

---

## 5. Kế hoạch kiểm thử & Đánh giá (Verification Plan)

### Kiểm thử tự động & Phân tích
- Chạy `flutter analyze` đảm bảo không có lỗi biên dịch.
- Kiểm tra tính ổn định của hàm RPC xếp hạng bài viết trên Supabase.

### Kiểm thử thủ công trên Web/App
1. **Kiểm tra độ đa dạng Feed**: Đăng nhiều bài từ cùng 1 tài khoản, lướt Feed để xác nhận các bài không bị xếp dồn cục liên tiếp.
2. **Kiểm tra tác động của Dwell Time**: Dừng lại xem 1 bài viết lâu hơn, F5 lại feed xem các bài viết cùng chủ đề/tác giả có được ưu tiên nâng điểm không.
