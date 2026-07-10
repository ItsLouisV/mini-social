import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/extensions/date_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../domain/post_model.dart';
import '../../providers/feed_provider.dart';
import '../widgets/image_carousel.dart';
import '../widgets/post_actions.dart';

class PostCard extends ConsumerWidget {
  final PostModel post;
  final String currentUserId;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = post.userId == currentUserId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Avatar & Thread Line
          Column(
            children: [
              AppAvatar(
                imageUrl: post.author?.avatarUrl,
                name: post.author?.displayName,
                radius: 20,
                onTap: () => context.push('/profile/${post.userId}'),
              ),
              const SizedBox(height: 8),
              // Visual thread line
              Container(
                width: 2,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Right Column: Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Name, Time, More
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.push('/profile/${post.userId}'),
                        child: Text(
                          post.author?.displayName ?? 'Unknown',
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      post.createdAt.timeAgo,
                      style: AppTextStyles.caption.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _getPrivacyIcon(post.privacy),
                      size: 10,
                      color: Theme.of(context).hintColor,
                    ),
                    const SizedBox(width: 8),
                    if (isOwner)
                      GestureDetector(
                        onTap: () => _showMoreOptions(context, ref),
                        child: const Icon(CupertinoIcons.ellipsis, size: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                // Caption
                if (post.caption?.isNotEmpty == true) ...[
                  Text(
                    post.caption!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Media (images & videos)
                if (post.media.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ImageCarousel(
                      media: post.media,
                    ),
                  ),

                // Actions
                PostActions(
                  post: post,
                  onCommentTap: () =>
                      context.push('/feed/post/${post.id}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context, WidgetRef ref) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              ctx.pop();
              _confirmDelete(context, ref);
            },
            child: const Text('Xóa bài viết'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => ctx.pop(),
          child: const Text('Hủy'),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Xóa bài viết'),
        content: const Text('Bạn có chắc muốn xóa bài viết này không?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => ctx.pop(),
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              ctx.pop();
              try {
                await ref
                    .read(postRepositoryProvider)
                    .deletePost(post.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Xóa thất bại: ${e.toString()}'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  IconData _getPrivacyIcon(String privacy) {
    switch (privacy) {
      case 'public':
        return CupertinoIcons.globe;
      case 'friends':
        return CupertinoIcons.person_2_fill;
      case 'followers':
        return CupertinoIcons.person_crop_circle_badge_checkmark;
      case 'private':
        return CupertinoIcons.lock_fill;
      default:
        return CupertinoIcons.globe;
    }
  }
}
