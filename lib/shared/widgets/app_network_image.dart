import 'dart:io' as io;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Cross-platform image widget.
/// On Web (kIsWeb), uses native browser Image.network to prevent WebGL texture eviction
/// and black rectangle rendering bugs on Web Mobile (Safari iOS / Mobile Chrome).
/// On Native apps, uses CachedNetworkImage for disk/memory caching.
class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final WidgetBuilder? placeholder;
  final WidgetBuilder? errorWidget;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return errorWidget?.call(context) ?? _defaultError(context);
    }

    final isHttp = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

    if (kIsWeb || !isHttp) {
      if (isHttp) {
        return Image.network(
          imageUrl,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) =>
              errorWidget?.call(context) ?? _defaultError(context),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return placeholder?.call(context) ?? _defaultPlaceholder(context);
          },
        );
      } else {
        return kIsWeb
            ? Image.network(imageUrl, width: width, height: height, fit: fit)
            : Image.file(io.File(imageUrl), width: width, height: height, fit: fit);
      }
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      useOldImageOnUrlChange: true,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: const Duration(milliseconds: 150),
      placeholder: (context, url) =>
          placeholder?.call(context) ?? _defaultPlaceholder(context),
      errorWidget: (context, url, error) =>
          errorWidget?.call(context) ?? _defaultError(context),
    );
  }

  Widget _defaultPlaceholder(BuildContext context) {
    return Container(
      color: Colors.grey.withValues(alpha: 0.15),
      child: const Center(child: CupertinoActivityIndicator(radius: 10)),
    );
  }

  Widget _defaultError(BuildContext context) {
    return Container(
      color: Colors.grey.withValues(alpha: 0.2),
      child: const Center(
        child: Icon(CupertinoIcons.photo, color: Colors.grey, size: 20),
      ),
    );
  }
}

/// Dynamic ImageProvider helper for CircleAvatar / NetworkImage fallback on Web vs Native
ImageProvider appNetworkImageProvider(String url) {
  if (kIsWeb || !url.startsWith('http')) {
    return NetworkImage(url);
  }
  return CachedNetworkImageProvider(url);
}
