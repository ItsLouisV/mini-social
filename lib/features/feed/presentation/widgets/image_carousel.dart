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
    if (widget.media.isEmpty) return const SizedBox.shrink();

    if (widget.media.length == 1) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: _buildMediaItem(context, 0),
      );
    }

    final bottomCount = (widget.media.length - 1).clamp(1, 3);

    return AspectRatio(
      aspectRatio: 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top item (2/3 of vertical space)
          Expanded(
            flex: 2,
            child: _buildMediaItem(context, 0),
          ),
          const SizedBox(height: 2),
          // Bottom items row (1/3 of vertical space)
          Expanded(
            flex: 1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(bottomCount, (index) {
                final mediaIndex = index + 1;
                final isLast = (index == bottomCount - 1);
                final showOverlay = isLast && index == 2 && widget.media.length > 4;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: isLast ? 0.0 : 2.0,
                    ),
                    child: _buildMediaItem(context, mediaIndex, showOverlay: showOverlay),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaItem(BuildContext context, int index, {bool showOverlay = false}) {
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

    if (showOverlay) {
      final remainingCount = widget.media.length - 4;
      mediaWidget = Stack(
        fit: StackFit.expand,
        children: [
          mediaWidget,
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            child: Text(
              '+$remainingCount',
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
