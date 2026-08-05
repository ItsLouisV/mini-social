import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton Loading dùng chung cho Hội thoại (Conversations) và Thông báo (Notifications)
class TileSkeletonLoading extends StatelessWidget {
  final int itemCount;
  final bool hasSearchBar;

  const TileSkeletonLoading({
    super.key,
    this.itemCount = 8,
    this.hasSearchBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2E2E3E) : const Color(0xFFE2E2E9);
    final highlightColor = isDark ? const Color(0xFF3F3F54) : const Color(0xFFF5F5FA);

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount + (hasSearchBar ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasSearchBar && index == 0) {
          return _buildSearchBarSkeleton(baseColor, highlightColor);
        }
        return _buildTileSkeleton(baseColor, highlightColor);
      },
    );
  }

  /// Skeleton cho khung tìm kiếm (search bar) ở trên danh sách hội thoại
  Widget _buildSearchBarSkeleton(Color baseColor, Color highlightColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// Component từng ô item skeleton dùng chung cho Conversation & Notification
  Widget _buildTileSkeleton(Color baseColor, Color highlightColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Avatar Placeholder (Hình tròn 48px) ──
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),

            // ── Content Columns (Name, Subtitle, Time) ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dòng tiêu đề (Tên hiển thị / Sender name)
                  Container(
                    width: 140,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Dòng phụ (Nội dung tin nhắn / Chi tiết thông báo)
                  Container(
                    width: double.infinity,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Dòng thời gian phụ (Time ago)
                  Container(
                    width: 65,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // ── Trailing Indicator (Giờ / Chevron / Dot) ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 35,
                  height: 11,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
