import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton Loading hiện đại, cao cấp dành riêng cho Trang Feed bài viết
class FeedSkeletonLoading extends StatelessWidget {
  final int itemCount;
  final bool showHeaderBar;

  const FeedSkeletonLoading({
    super.key,
    this.itemCount = 3,
    this.showHeaderBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2E2E3E) : const Color(0xFFE2E2E9);
    final highlightColor = isDark ? const Color(0xFF3F3F54) : const Color(0xFFF5F5FA);
    final cardBgColor = isDark ? const Color(0xFF1E1E2A) : Colors.white;

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: itemCount + (showHeaderBar ? 1 : 0),
      itemBuilder: (context, index) {
        if (showHeaderBar && index == 0) {
          return _buildHeaderBarSkeleton(cardBgColor, baseColor, highlightColor);
        }
        return _buildPostCardSkeleton(cardBgColor, baseColor, highlightColor);
      },
    );
  }

  /// Skeleton cho thanh "Bạn đang nghĩ gì?" ở đầu trang Feed
  Widget _buildHeaderBarSkeleton(Color cardBgColor, Color baseColor, Color highlightColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Skeleton mô phỏng tinh xảo khung bài viết (PostCard)
  Widget _buildPostCardSkeleton(Color cardBgColor, Color baseColor, Color highlightColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header (Avatar, Name, Time, 3-dots) ──
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 140,
                        height: 14,
                        decoration: BorderRadius.circular(6).toBoxDecoration(),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 80,
                        height: 11,
                        decoration: BorderRadius.circular(4).toBoxDecoration(),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Caption (2 dòng chữ mô phỏng bài đăng) ──
            Container(
              width: double.infinity,
              height: 13,
              decoration: BorderRadius.circular(4).toBoxDecoration(),
            ),
            const SizedBox(height: 8),
            FractionallySizedBox(
              widthFactor: 0.65,
              child: Container(
                height: 13,
                decoration: BorderRadius.circular(4).toBoxDecoration(),
              ),
            ),

            const SizedBox(height: 16),

            // ── Media Placeholder Container (Hình ảnh/Video đăng) ──
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Icon(
                  CupertinoIcons.photo,
                  size: 40,
                  color: baseColor.withValues(alpha: 0.3),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Action Buttons Bar (Like, Comment, Share icons) ──
            Row(
              children: [
                // Nút Like
                Container(
                  width: 72,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(width: 10),
                // Nút Comment
                Container(
                  width: 72,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const Spacer(),
                // Nút Share
                Container(
                  width: 38,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
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

extension _BorderRadiusExt on BorderRadius {
  BoxDecoration toBoxDecoration() => BoxDecoration(color: Colors.white, borderRadius: this);
}
