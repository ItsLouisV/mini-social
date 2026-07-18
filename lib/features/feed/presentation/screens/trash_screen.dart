import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/extensions/date_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../domain/post_model.dart';
import '../../providers/feed_provider.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final trashedAsync = ref.watch(trashedPostsProvider);

    final groupedBg = theme.scaffoldBackgroundColor;
    final cardBg = theme.colorScheme.surface;

    return CupertinoPageScaffold(
      backgroundColor: groupedBg,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: groupedBg.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.pop(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.chevron_back,
                  color: theme.colorScheme.primary, size: 18),
              const SizedBox(width: 4),
              Text(
                'Quay lại',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        middle: const Text(
          'Thùng rác bài viết',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: trashedAsync.when(
            data: (posts) {
              if (posts.isEmpty) {
                return const EmptyStateWidget(
                  icon: CupertinoIcons.trash,
                  title: 'Thùng rác trống',
                  subtitle: 'Các bài viết bạn chuyển vào thùng rác sẽ xuất hiện tại đây',
                );
              }

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.1),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.info, size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Các mục trong thùng rác sẽ tự động bị xóa vĩnh viễn sau 30 ngày.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        return _buildTrashedPostTile(context, ref, post);
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (e, _) => AppErrorWidget(
              message: e.toString(),
              onRetry: () => ref.invalidate(trashedPostsProvider),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrashedPostTile(BuildContext context, WidgetRef ref, PostModel post) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Đếm ngược 30 ngày
    int daysLeft = 30;
    if (post.createdAt != null) {
      final diff = DateTime.now().difference(post.createdAt).inDays;
      daysLeft = (30 - diff).clamp(1, 30);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: isDark ? 0.08 : 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Days left
          Row(
            children: [
              AppAvatar(
                imageUrl: post.author?.avatarUrl,
                name: post.author?.displayName,
                radius: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  post.author?.displayName ?? 'Bài viết của bạn',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Xóa sau $daysLeft ngày',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Caption Text preview
          if (post.caption?.isNotEmpty == true) ...[
            Text(
              post.caption!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Media Thumbnail preview
          if (post.media.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: post.media.first.url,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          const Divider(height: 16),

          // Actions: Khôi phục / Xóa vĩnh viễn
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 14),
                label: const Text('Khôi phục', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () async {
                  try {
                    await ref.read(postRepositoryProvider).restoreFromTrash(post.id);
                    ref.read(postLocalStatesProvider.notifier).undo(post.id);
                    ref.invalidate(trashedPostsProvider);
                    ref.invalidate(feedPostsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã khôi phục bài viết về bảng tin.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi khôi phục: $e')),
                      );
                    }
                  }
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(CupertinoIcons.trash, size: 14, color: Colors.white),
                label: const Text('Xóa vĩnh viễn', style: TextStyle(fontSize: 12, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  _confirmPermanentDelete(context, ref, post.id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmPermanentDelete(BuildContext context, WidgetRef ref, String postId) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Xóa vĩnh viễn?'),
        content: const Text('Bài viết này sẽ bị xóa hoàn toàn và không thể khôi phục lại nữa.'),
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
                await ref.read(postRepositoryProvider).deletePost(postId);
                ref.invalidate(trashedPostsProvider);
                ref.invalidate(feedPostsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xóa vĩnh viễn bài viết.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi xóa vĩnh viễn: $e')),
                  );
                }
              }
            },
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
  }
}
