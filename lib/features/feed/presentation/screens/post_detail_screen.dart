import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/extensions/date_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/comment_model.dart';
import '../../domain/post_model.dart';
import '../../providers/feed_provider.dart';
import '../widgets/image_carousel.dart';
import '../widgets/post_actions.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ref
          .read(postRepositoryProvider)
          .addComment(widget.postId, text);
      _commentController.clear();
      ref.invalidate(commentsProvider(widget.postId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final commentsAsync = ref.watch(commentsProvider(widget.postId));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bài viết'),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: postAsync.when(
              data: (post) => _buildContent(context, ref, post, commentsAsync, currentUserId),
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (e, _) => AppErrorWidget(message: e.toString()),
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, PostModel post,
      AsyncValue<List<CommentModel>> commentsAsync, String? currentUserId) {
    return ListView(
      children: [
        // Post header
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AppAvatar(
                imageUrl: post.author?.avatarUrl,
                name: post.author?.displayName,
                radius: 20,
                onTap: () => context.push('/profile/${post.userId}'),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.author?.displayName ?? '', style: AppTextStyles.titleSmall),
                  Text(post.createdAt.timeAgo, style: AppTextStyles.caption),
                ],
              ),
            ],
          ),
        ),

        if (post.caption?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(post.caption!, style: AppTextStyles.bodyMedium),
          ),

        if (post.media.isNotEmpty)
          ImageCarousel(media: post.media),

        PostActions(post: post),

        const Divider(height: 1),

        // Comments
        commentsAsync.when(
          data: (comments) {
            if (comments.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('Chưa có bình luận nào',
                      style: AppTextStyles.bodySmall),
                ),
              );
            }
            return Column(
              children: comments
                  .map((c) => _CommentTile(
                        comment: c,
                        currentUserId: currentUserId,
                        onDelete: () async {
                          await ref
                              .read(postRepositoryProvider)
                              .deleteComment(c.id);
                          ref.invalidate(commentsProvider(widget.postId));
                        },
                      ))
                  .toList(),
            );
          },
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (e, _) => const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Viết bình luận...',
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: Theme.of(context).hintColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _addComment(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _addComment,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: _sending
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                    )
                  : const Icon(CupertinoIcons.paperplane_fill, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentModel comment;
  final String? currentUserId;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    this.currentUserId,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = comment.userId == currentUserId;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(
            imageUrl: comment.author?.avatarUrl,
            name: comment.author?.displayName,
            radius: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(comment.author?.displayName ?? '',
                          style: AppTextStyles.labelMedium),
                      const SizedBox(width: 6),
                      Text(comment.createdAt.timeAgo,
                          style: AppTextStyles.caption),
                      if (isOwner) ...[
                        const Spacer(),
                        GestureDetector(
                          onTap: onDelete,
                          child: Icon(CupertinoIcons.xmark,
                              size: 14, color: Theme.of(context).hintColor),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(comment.content, style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
