import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/extensions/string_extension.dart';

class AppAvatar extends StatelessWidget {
  static const int _sharedDecodeSize = 256;

  final String? imageUrl;
  final String? name;
  final double radius;
  final VoidCallback? onTap;
  final bool showBorder;

  const AppAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 20,
    this.onTap,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    final logicalSize = radius * 2;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatar = SizedBox.square(
        dimension: logicalSize,
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          // Mọi kích thước AppAvatar dùng chung một biến thể cache. Nếu tính
          // theo radius, cùng URL ở danh sách chat (r=25) và app bar (r=19)
          // sẽ bị decode lại khi chuyển màn hình và gây chớp placeholder.
          memCacheWidth: _sharedDecodeSize,
          memCacheHeight: _sharedDecodeSize,
          maxWidthDiskCache: _sharedDecodeSize,
          maxHeightDiskCache: _sharedDecodeSize,
          useOldImageOnUrlChange: true,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          imageBuilder: (context, imageProvider) => CircleAvatar(
            radius: radius,
            backgroundImage: imageProvider,
          ),
          placeholder: (context, url) => _buildPlaceholder(context),
          errorWidget: (context, url, error) => _buildInitials(context),
        ),
      );
    } else {
      avatar = _buildInitials(context);
    }

    if (showBorder) {
      avatar = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: avatar,
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _buildPlaceholder(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const CupertinoActivityIndicator(),
    );
  }

  Widget _buildInitials(BuildContext context) {
    final initials = name?.initials ?? '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
      child: Text(
        initials,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: radius * 0.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
