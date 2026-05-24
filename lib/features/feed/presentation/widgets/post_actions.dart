import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../../../core/constants/app_text_styles.dart';
import '../../domain/post_model.dart';
import '../../providers/feed_provider.dart';

class PostActions extends ConsumerWidget {
  final PostModel post;
  final VoidCallback? onCommentTap;

  const PostActions({
    super.key,
    required this.post,
    this.onCommentTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likeState = ref.watch(likeNotifierProvider(post.id));
    final isLiked = likeState.value ?? post.isLiked;
    int likesCount = post.likesCount;
    if (likeState.value != null && likeState.value != post.isLiked) {
      likesCount += (likeState.value == true) ? 1 : -1;
    }
    if (likesCount < 0) likesCount = 0;

    final commentsAsync = ref.watch(commentsProvider(post.id));
    final commentCount = commentsAsync.value?.length ?? post.commentsCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          // Like button with live count
          _ActionButton(
            icon: isLiked
                ? CupertinoIcons.heart_fill
                : CupertinoIcons.heart,
            color: isLiked ? Colors.red : Theme.of(context).hintColor,
            label: '$likesCount',
            onTap: () =>
                ref.read(likeNotifierProvider(post.id).notifier).toggle(isLiked),
          ),
          const SizedBox(width: 4),

          // Comment button with live count
          _ActionButton(
            icon: CupertinoIcons.chat_bubble,
            color: Theme.of(context).hintColor,
            label: '$commentCount',
            onTap: onCommentTap,
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: 1),
              duration: const Duration(milliseconds: 150),
              builder: (_, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
