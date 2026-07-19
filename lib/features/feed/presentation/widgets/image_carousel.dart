import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../screens/gallery_screen.dart';
import '../../domain/post_model.dart';
import '../../../../shared/widgets/app_video_player.dart';
import '../../../../core/constants/app_colors.dart';

class ImageCarousel extends StatefulWidget {
  final List<PostMedia> media;
  final String layoutType;

  const ImageCarousel({
    super.key,
    required this.media,
    this.layoutType = 'dashboard',
  });

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

    // ── 3+ MỤC MEDIA (Tự chọn Layout theo 4 bản vẽ) ──
    switch (widget.layoutType) {
      case 'columns':
      case 'columns-3':
      case 'vertical':
        return _buildColumnsLayout(context);

      case 'panel-left':
      case 'layout-panel-left':
      case 'hero':
        return _buildPanelLeftLayout(context);

      case 'panel-top':
      case 'layout-panel-top':
      case 'horizontal':
        return _buildPanelTopLayout(context);

      case 'dashboard':
      case 'layout-dashboard':
      case 'grid':
      default:
        return _buildDashboardLayout(context);
    }
  }

  // ── 1 ảnh/video ──
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

  // ── 2 ảnh/video ──
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

  // ── 1. BẢN VẼ 1: Dashboard (`layout-dashboard`) ──
  // - 3 ảnh: Cột trái (2 ảnh nhỏ vuông/chữ nhật chồng) + Cột phải (1 ảnh cao full)
  // - >= 4 ảnh: Cột trái (1 ảnh cao top + 1 ảnh nhỏ bottom) + Cột phải (1 ảnh nhỏ top + 1 ảnh dưới kèm +N)
  Widget _buildDashboardLayout(BuildContext context) {
    final count = widget.media.length;

    if (count == 3) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cột trái: 2 ảnh nhỏ chồng lên nhau
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildMediaItem(context, 0)),
                  const SizedBox(height: 2),
                  Expanded(child: _buildMediaItem(context, 1)),
                ],
              ),
            ),
            const SizedBox(width: 2),
            // Cột phải: 1 ảnh cao full
            Expanded(
              flex: 1,
              child: _buildMediaItem(context, 2),
            ),
          ],
        ),
      );
    }

    // >= 4 ảnh
    final remainingCount = count - 4;
    return AspectRatio(
      aspectRatio: 1.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cột trái: Image 0 (cao flex 2) + Image 2 (vuông flex 1)
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: _buildMediaItem(context, 0)),
                const SizedBox(height: 2),
                Expanded(flex: 1, child: _buildMediaItem(context, 2)),
              ],
            ),
          ),
          const SizedBox(width: 2),
          // Cột phải: Image 1 (vuông flex 1) + Image 3 (cao flex 2 kèm +N)
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 1, child: _buildMediaItem(context, 1)),
                const SizedBox(height: 2),
                Expanded(
                  flex: 2,
                  child: _buildMediaItem(
                    context,
                    3,
                    overlayText: remainingCount > 0 ? '+$remainingCount' : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. BẢN VẼ 2: Columns (`columns-3`) ──
  // - 3 ảnh: 3 cột đứng song song
  // - 4 ảnh: 4 cột đứng song song
  // - > 4 ảnh: 4 cột đứng song song với cột thứ 4 có "+ số ảnh còn lại"
  // ── 2. BẢN VẼ 2: Columns (`columns-3`) (Nhô cao & nhô xuống rõ nét) ──
  Widget _buildColumnsLayout(BuildContext context) {
    final count = widget.media.length;
    final showCount = count >= 4 ? 4 : (count == 3 ? 3 : count);
    final remainingCount = count - 4;

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < showCount; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  top: i % 2 == 1 ? 32.0 : 0.0,
                  bottom: i % 2 == 0 ? 32.0 : 0.0,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMediaItem(
                    context,
                    i,
                    overlayText: (i == 3 && remainingCount > 0) ? '+$remainingCount' : null,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 3. BẢN VẼ 3: Panel Left (`layout-panel-left`) ──
  // - Bên trái: 1 ảnh/video lớn (Hero) (~60% chiều rộng)
  // - Bên phải: 
  //   + 3 ảnh: 2 ảnh nhỏ xếp dọc
  //   + 4 ảnh: 3 ảnh nhỏ xếp dọc (không +)
  //   + > 4 ảnh: 3 ảnh nhỏ xếp dọc (ảnh thứ 3 có + số ảnh còn lại)
  Widget _buildPanelLeftLayout(BuildContext context) {
    final count = widget.media.length;
    final rightCount = count >= 4 ? 3 : 2;
    final remainingCount = count - 4;

    return AspectRatio(
      aspectRatio: 1.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bên trái: Ảnh Hero lớn
          Expanded(
            flex: 6,
            child: _buildMediaItem(context, 0),
          ),
          const SizedBox(width: 2),
          // Bên phải: Các ảnh nhỏ xếp dọc
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 1; i <= rightCount; i++) ...[
                  if (i > 1) const SizedBox(height: 2),
                  Expanded(
                    child: _buildMediaItem(
                      context,
                      i,
                      overlayText: (i == 3 && remainingCount > 0) ? '+$remainingCount' : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. BẢN VẼ 4: Panel Top (`layout-panel-top`) ──
  // - Phía trên: 1 ảnh/video banner lớn (Hero) (~60% chiều cao)
  // - Phía dưới:
  //   + 3 ảnh: 2 ảnh nhỏ xếp ngang
  //   + >= 4 ảnh: 3 ảnh nhỏ xếp ngang (ảnh thứ 3 có + số ảnh còn lại nếu > 4)
  Widget _buildPanelTopLayout(BuildContext context) {
    final count = widget.media.length;
    final bottomCount = count >= 4 ? 3 : 2;
    final remainingCount = count - 4;

    return AspectRatio(
      aspectRatio: 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Phía trên: Banner Hero lớn
          Expanded(
            flex: 6,
            child: _buildMediaItem(context, 0),
          ),
          const SizedBox(height: 2),
          // Phía dưới: Hàng các ảnh nhỏ xếp ngang
          Expanded(
            flex: 4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 1; i <= bottomCount; i++) ...[
                  if (i > 1) const SizedBox(width: 2),
                  Expanded(
                    child: _buildMediaItem(
                      context,
                      i,
                      overlayText: (i == 3 && remainingCount > 0) ? '+$remainingCount' : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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

    final isNetwork = item.url.startsWith('http://') || item.url.startsWith('https://');

    Widget mediaWidget;
    if (isVideo) {
      if (isNetwork) {
        mediaWidget = AppVideoPlayer(url: item.url);
      } else {
        mediaWidget = Container(
          color: Colors.black87,
          child: const Center(
            child: Icon(CupertinoIcons.play_circle_fill, size: 44, color: Colors.white),
          ),
        );
      }
    } else {
      if (isNetwork) {
        mediaWidget = CachedNetworkImage(
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
      } else {
        mediaWidget = kIsWeb
            ? Image.network(item.url, fit: BoxFit.cover)
            : Image.file(io.File(item.url), fit: BoxFit.cover);
      }
    }

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
                fontSize: 22,
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
