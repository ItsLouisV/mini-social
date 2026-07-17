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
    final theme = Theme.of(context);

    final likeState = ref.watch(likeNotifierProvider(post.id));
    final isLiked = likeState.value ?? post.isLiked;
    int likesCount = post.likesCount;
    if (likeState.value != null && likeState.value != post.isLiked) {
      likesCount += (likeState.value == true) ? 1 : -1;
    }
    if (likesCount < 0) likesCount = 0;

    final commentsAsync = ref.watch(commentsProvider(post.id));
    final commentCount = commentsAsync.value?.length ?? post.commentsCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Likes & Comments Count Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (likesCount > 0) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.hand_thumbsup_fill,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$likesCount',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                    fontSize: 12,
                  ),
                ),
              ] else ...[
                Text(
                  'Hãy là người đầu tiên thích',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
              const Spacer(),
              if (commentCount > 0)
                Text(
                  '$commentCount bình luận',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        
        // Divider
        Divider(
          height: 1,
          thickness: 0.5,
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),

        // Actions Row: Thích, Bình luận, Chia sẻ
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Like Button
              Expanded(
                child: InkWell(
                  onTap: () => ref.read(likeNotifierProvider(post.id).notifier).toggle(isLiked),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isLiked ? CupertinoIcons.hand_thumbsup_fill : CupertinoIcons.hand_thumbsup,
                          size: 20,
                          color: isLiked ? Colors.blue : theme.hintColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Thích',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isLiked ? Colors.blue : theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Comment Button
              Expanded(
                child: InkWell(
                  onTap: onCommentTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.chat_bubble,
                          size: 20,
                          color: theme.hintColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Bình luận',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Share Button
              Expanded(
                child: InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã sao chép liên kết chia sẻ bài viết!')),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.arrowshape_turn_up_right,
                          size: 20,
                          color: theme.hintColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Chia sẻ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
