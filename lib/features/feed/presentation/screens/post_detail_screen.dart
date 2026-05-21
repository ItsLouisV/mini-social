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

class CommentNode {
  final CommentModel comment;
  int level;
  List<CommentNode> children;

  CommentNode(this.comment, {this.level = 1, List<CommentNode>? children})
      : children = children ?? [];
}

List<CommentNode> buildCommentTree(List<CommentModel> comments) {
  final map = <String, CommentNode>{};
  final roots = <CommentNode>[];

  // Pass 1: create nodes
  for (var c in comments) {
    map[c.id] = CommentNode(c, level: 1);
  }

  // Pass 2: assign children
  for (var c in comments) {
    final node = map[c.id]!;
    if (c.parentId == null) {
      roots.add(node);
    } else {
      final parent = map[c.parentId];
      if (parent != null) {
        node.level = parent.level + 1;
        parent.children.add(node);
      } else {
        roots.add(node); // Orphan fallback
      }
    }
  }

  return roots;
}

List<CommentNode> flattenTree(List<CommentNode> roots) {
  final result = <CommentNode>[];
  void traverse(CommentNode node) {
    result.add(node);
    for (var child in node.children) {
      traverse(child);
    }
  }
  for (var r in roots) traverse(r);
  return result;
}

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _focusNode = FocusNode();
  bool _sending = false;
  CommentModel? _replyingTo;

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setReply(CommentModel comment) {
    setState(() {
      _replyingTo = comment;
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ref
          .read(postRepositoryProvider)
          .addComment(widget.postId, text, parentId: _replyingTo?.id);
      _commentController.clear();
      _cancelReply();
      _focusNode.unfocus();
      ref.invalidate(commentsProvider(widget.postId));
      ref.invalidate(postDetailProvider(widget.postId));
      ref.invalidate(feedPostsProvider);
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

        // Comments Section
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
            
            final tree = buildCommentTree(comments);
            final flattened = flattenTree(tree);

            return Padding(
              padding: const EdgeInsets.only(bottom: 24), // padding for bottom scrolling
              child: Column(
                children: flattened
                    .map((node) => _CommentTile(
                          node: node,
                          currentUserId: currentUserId,
                          onReply: () => _setReply(node.comment),
                          onDelete: () async {
                            await ref
                                .read(postRepositoryProvider)
                                .deleteComment(node.comment.id);
                            ref.invalidate(commentsProvider(widget.postId));
                            ref.invalidate(postDetailProvider(widget.postId));
                            ref.invalidate(feedPostsProvider);
                          },
                          onLikeToggle: () async {
                            try {
                              final repo = ref.read(postRepositoryProvider);
                              if (node.comment.isLiked) {
                                await repo.unlikeComment(node.comment.id);
                              } else {
                                await repo.likeComment(node.comment.id);
                              }
                              ref.invalidate(commentsProvider(widget.postId));
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Lỗi khi thích: $e'),
                                    backgroundColor: Theme.of(context).colorScheme.error,
                                  ),
                                );
                              }
                            }
                          }
                        ))
                    .toList(),
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CupertinoActivityIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Đang trả lời ${_replyingTo!.author?.displayName ?? ''}',
                        style: AppTextStyles.caption.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _cancelReply,
                      child: Icon(CupertinoIcons.xmark_circle_fill, size: 18, color: Theme.of(context).hintColor),
                    )
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _focusNode,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentNode node;
  final String? currentUserId;
  final VoidCallback onDelete;
  final VoidCallback onReply;
  final VoidCallback onLikeToggle;

  const _CommentTile({
    required this.node,
    this.currentUserId,
    required this.onDelete,
    required this.onReply,
    required this.onLikeToggle,
  });

  @override
  Widget build(BuildContext context) {
    final comment = node.comment;
    final isOwner = comment.userId == currentUserId;
    
    // Level 1: marginLeft = 0, radius = 18
    // Level 2: marginLeft = 40, radius = 14
    // Level 3: marginLeft = 80, radius = 14
    final maxLevel = 3;
    final level = node.level > maxLevel ? maxLevel : node.level;
    final indent = (level - 1) * 40.0;
    final avatarRadius = level == 1 ? 18.0 : 14.0;
    
    final canReply = level < maxLevel;

    return Padding(
      padding: EdgeInsets.only(left: 12 + indent, right: 12, top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(
            imageUrl: comment.author?.avatarUrl,
            name: comment.author?.displayName,
            radius: avatarRadius,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(comment.author?.displayName ?? '',
                              style: AppTextStyles.titleSmall),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text('•', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ),
                          Text(comment.createdAt.timeAgo,
                              style: AppTextStyles.caption.copyWith(fontSize: 11)),
                          const Spacer(),
                          if (isOwner)
                            GestureDetector(
                              onTap: onDelete,
                              child: Icon(CupertinoIcons.trash,
                                  size: 14, color: Theme.of(context).hintColor),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(comment.content, style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
                // Actions (Reply, Like)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Row(
                    children: [
                      if (canReply)
                        GestureDetector(
                          onTap: onReply,
                          child: Text(
                            'Trả lời',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const Spacer(),
                      GestureDetector(
                        onTap: onLikeToggle,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (comment.likesCount > 0) ...[
                              Text(
                                '${comment.likesCount}',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 12,
                                  fontWeight: comment.isLiked ? FontWeight.w600 : FontWeight.w500,
                                  color: comment.isLiked 
                                      ? Theme.of(context).colorScheme.primary 
                                      : Theme.of(context).hintColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Icon(
                              comment.isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                              size: 16,
                              color: comment.isLiked 
                                  ? Theme.of(context).colorScheme.primary 
                                  : Theme.of(context).hintColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
