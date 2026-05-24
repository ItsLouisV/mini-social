import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/notifications.dart';


import '../../../../core/constants/app_text_styles.dart';

class FeedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onSearchTap;
  final VoidCallback? onNotificationTap;

  const FeedAppBar({
    super.key,
    required this.onSearchTap,
    this.onNotificationTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(CupertinoIcons.bars),
        onPressed: () => const OpenDrawerNotification().dispatch(context),
      ),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text('MiniSocial', style: AppTextStyles.headlineMedium),
        ],
      ),
      actions: [
        IconButton(
          onPressed: onSearchTap,
          icon: const Icon(CupertinoIcons.search),
          tooltip: 'Tìm kiếm',
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
