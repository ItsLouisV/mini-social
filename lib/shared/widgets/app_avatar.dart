import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/extensions/string_extension.dart';

class AppAvatar extends StatelessWidget {

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

    final hasValidUrl = imageUrl != null &&
        imageUrl!.isNotEmpty &&
        (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://'));

    if (hasValidUrl) {
      if (kIsWeb) {
        avatar = SizedBox.square(
          dimension: logicalSize,
          child: ClipOval(
            child: Image.network(
              imageUrl!,
              width: logicalSize,
              height: logicalSize,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildInitials(context),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _buildPlaceholder(context);
              },
            ),
          ),
        );
      } else {
        avatar = SizedBox.square(
          dimension: logicalSize,
          child: CachedNetworkImage(
            imageUrl: imageUrl!,
            useOldImageOnUrlChange: true,
            fadeInDuration: const Duration(milliseconds: 150),
            fadeOutDuration: const Duration(milliseconds: 150),
            imageBuilder: (context, imageProvider) => CircleAvatar(
              radius: radius,
              backgroundImage: imageProvider,
            ),
            placeholder: (context, url) => _buildPlaceholder(context),
            errorWidget: (context, url, error) => _buildInitials(context),
          ),
        );
      }
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
