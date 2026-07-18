import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../screens/gallery_screen.dart';
import '../../domain/post_model.dart';
import '../../../../shared/widgets/app_video_player.dart';
import '../../../../core/constants/app_colors.dart';

class ImageCarousel extends StatefulWidget {
  final List<PostMedia> media;

  const ImageCarousel({super.key, required this.media});

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  @override
  Widget build(BuildContext context) {
    final mediaList = widget.media;
    if (mediaList.isEmpty) return const SizedBox.shrink();

    final count = mediaList.length;

    // ── 1. ĐƠN (1 MỤC MEDIA) ──
    if (count == 1) {
      return _buildSingleMedia(context);
    }

    // ── 2. ĐÔI (2 MỤC MEDIA) ──
    if (count == 2) {
      return _buildTwoMedia(context);
    }

    // ── 3. BỘ 3 (3 MỤC MEDIA) ──
    if (count == 3) {
      return _buildThreeMedia(context);
    }

    // ── 4. BỘ 4 (ĐÚNG 4 MỤC MEDIA) ──
    if (count == 4) {
      return _buildFourMedia(context);
    }

    // ── 5. BỘ 5+ (TỪ 5 MỤC MEDIA TRỞ LÊN) ──
    return _buildFiveOrMoreMedia(context);
  }

  // ── 1 ảnh/video: Khung hình co giãn tự nhiên (tối đa 520px) ──
  Widget _buildSingleMedia(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: 620,
        minHeight: 200,
      ),
      child: SizedBox(
        width: double.infinity,
        child: _buildMediaItem(context, 0),
      ),
    );
  }

  // ── 2 ảnh/video: Chia đôi 2 cột bằng nhau chuẩn Facebook ──
  Widget _buildTwoMedia(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 2,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildMediaItem(context, 0)),
          const SizedBox(width: 2),
          Expanded(child: _buildMediaItem(context, 1)),
        ],
      ),
    );
  }

  // ── 3 ảnh/video: Layout 1 lớn bên trái + 2 nhỏ chồng bên phải ──
  Widget _buildThreeMedia(BuildContext context) {
    final useLeftHero = widget.media.hashCode % 2 == 0;

    if (useLeftHero) {
      // 1 ảnh lớn trái, 2 ảnh phải
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: _buildMediaItem(context, 0),
            ),
            const SizedBox(width: 2),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildMediaItem(context, 1)),
                  const SizedBox(height: 2),
                  Expanded(child: _buildMediaItem(context, 2)),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // 1 ảnh lớn trên, 2 ảnh dưới
      return AspectRatio(
        aspectRatio: 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: _buildMediaItem(context, 0),
            ),
            const SizedBox(height: 2),
            Expanded(
              flex: 1,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildMediaItem(context, 1)),
                  const SizedBox(width: 2),
                  Expanded(child: _buildMediaItem(context, 2)),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  // ── 4 ảnh: Thay đổi linh hoạt giữa Lưới 2x2 hoặc 1 Trên + 3 Dưới ──
  Widget _buildFourMedia(BuildContext context) {
    final isGridMode = widget.media.hashCode % 2 == 0;

    if (isGridMode) {
      // Lưới 2x2 vuông vắn
      return AspectRatio(
        aspectRatio: 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildMediaItem(context, 0)),
                  const SizedBox(width: 2),
                  Expanded(child: _buildMediaItem(context, 1)),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildMediaItem(context, 2)),
                  const SizedBox(width: 2),
                  Expanded(child: _buildMediaItem(context, 3)),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // 1 ảnh lớn trên + 3 ảnh dưới
      return AspectRatio(
        aspectRatio: 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: _buildMediaItem(context, 0),
            ),
            const SizedBox(height: 2),
            Expanded(
              flex: 1,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildMediaItem(context, 1)),
                  const SizedBox(width: 2),
                  Expanded(child: _buildMediaItem(context, 2)),
                  const SizedBox(width: 2),
                  Expanded(child: _buildMediaItem(context, 3)),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  // ── 5+ ảnh: Tùy biến linh hoạt layout kèm ô hiển thị "+X" ──
  Widget _buildFiveOrMoreMedia(BuildContext context) {
    final isTopThreeMode = widget.media.hashCode % 2 == 0;

    if (isTopThreeMode) {
      // Layout A: 1 Trên (2/3 height) + 3 Dưới (1/3 height) với ô thứ 4 hiện "+X"
      final remainingCount = widget.media.length - 4;
      return AspectRatio(
        aspectRatio: 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: _buildMediaItem(context, 0),
            ),
            const SizedBox(height: 2),
            Expanded(
              flex: 1,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildMediaItem(context, 1)),
                  const SizedBox(width: 2),
                  Expanded(child: _buildMediaItem(context, 2)),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _buildMediaItem(
                      context,
                      3,
                      overlayText: '+$remainingCount',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Layout B: 2 Trên + 3 Dưới với ô thứ 5 hiện "+X"
      final remainingCount = widget.media.length - 5;
      return AspectRatio(
        aspectRatio: 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildMediaItem(context, 0)),
                  const SizedBox(width: 2),
                  Expanded(child: _buildMediaItem(context, 1)),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildMediaItem(context, 2)),
                  const SizedBox(width: 2),
                  Expanded(child: _buildMediaItem(context, 3)),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _buildMediaItem(
                      context,
                      4,
                      overlayText: '+$remainingCount',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  // ── Widget hiển thị từng ảnh/video ──
  Widget _buildMediaItem(
    BuildContext context,
    int index, {
    String? overlayText,
  }) {
    final item = widget.media[index];
    final isVideo = item.type == 'video';
    final imagesOnly = widget.media.where((m) => m.type == 'image').toList();
    final imageIndex = imagesOnly.indexOf(item);

    Widget mediaWidget = isVideo
        ? AppVideoPlayer(url: item.url)
        : CachedNetworkImage(
            imageUrl: item.url,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: AppColors.shimmerBase,
            ),
            errorWidget: (_, __, ___) => Container(
              color: AppColors.surfaceVariant,
              child: const Icon(
                CupertinoIcons.photo,
                color: AppColors.textHint,
              ),
            ),
          );

    if (overlayText != null) {
      mediaWidget = Stack(
        fit: StackFit.expand,
        children: [
          mediaWidget,
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            child: Text(
              overlayText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: isVideo
          ? null
          : () {
              if (imageIndex != -1) {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => GalleryScreen(
                      imageUrls: imagesOnly.map((m) => m.url).toList(),
                      initialIndex: imageIndex,
                    ),
                  ),
                );
              }
            },
      child: mediaWidget,
    );
  }
}
