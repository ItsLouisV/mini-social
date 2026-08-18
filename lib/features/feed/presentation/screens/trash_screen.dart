import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../domain/post_model.dart';
import '../../providers/feed_provider.dart';

class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  static const _retentionPeriod = Duration(days: 30);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final posts = ref.watch(trashedPostsProvider);
    return CupertinoPageScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: .94),
        border: Border(
            bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: .35), width: .5)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.pop(),
          child: Icon(CupertinoIcons.chevron_back,
              color: theme.colorScheme.primary),
        ),
        middle: Text(AppTranslations.tr(ref, 'trash'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: posts.when(
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (error, _) => AppErrorWidget(
              message: error.toString(),
              onRetry: () => ref.invalidate(trashedPostsProvider),
            ),
            data: (items) => RefreshIndicator.adaptive(
              onRefresh: () => ref.refresh(trashedPostsProvider.future),
              child: items.isEmpty ? _empty(theme) : _content(theme, items),
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(ThemeData theme) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 100, 28, 32),
        children: [
          Container(
            width: 84,
            height: 84,
            margin: const EdgeInsets.only(bottom: 22),
            decoration: BoxDecoration(
                color:
                    theme.colorScheme.primaryContainer.withValues(alpha: .55),
                shape: BoxShape.circle),
            child: Icon(CupertinoIcons.trash,
                size: 38, color: theme.colorScheme.primary),
          ),
          Text(AppTranslations.tr(ref, 'empty_trash'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            'Những bài viết bạn xóa sẽ xuất hiện ở đây trong 30 ngày trước khi bị xóa vĩnh viễn.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.45, color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      );

  Widget _content(ThemeData theme, List<PostModel> posts) => ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: posts.length + 1,
        itemBuilder: (_, index) {
          if (index == 0) {
            return _banner(theme);
          }
          final post = posts[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _postCard(theme, post),
          );
        },
      );

  Widget _banner(ThemeData theme) {
    final colors = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.info_circle_fill,
            size: 20,
            color: colors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tất cả bài viết trong thùng rác sẽ tự động bị xóa vĩnh viễn sau 30 ngày',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _postCard(ThemeData theme, PostModel post) {
    final colors = theme.colorScheme;
    final deadline = post.deletedAt?.add(_retentionPeriod);
    final remaining = deadline?.difference(DateTime.now());
    final urgent = remaining != null && remaining <= const Duration(days: 3);
    final progress = remaining == null
        ? 0.0
        : (remaining.inSeconds / _retentionPeriod.inSeconds).clamp(0.0, 1.0);
    final hasCaption = post.caption?.trim().isNotEmpty == true;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
        boxShadow: [
          BoxShadow(
              color: colors.shadow.withValues(
                  alpha: theme.brightness == Brightness.dark ? .16 : .06),
              blurRadius: 18,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (post.media.isNotEmpty) _thumbnail(theme, post),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(
                hasCaption
                    ? post.caption!.trim()
                    : 'Bài viết không có nội dung',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: hasCaption
                        ? colors.onSurface
                        : colors.onSurfaceVariant),
              )),
              const SizedBox(width: 12),
              _countdownBadge(theme, remaining, urgent),
            ]),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: colors.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                    urgent ? colors.error : colors.primary),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Icon(CupertinoIcons.clock,
                  size: 15, color: colors.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(
                deadline == null
                    ? 'Chưa xác định được thời hạn xóa'
                    : 'Xóa vĩnh viễn lúc ${_formatDateTime(deadline.toLocal())}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              )),
            ]),
          ]),
        ),
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: .5)),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Expanded(
                child: TextButton.icon(
              onPressed: () => _restore(post.id),
              icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 18),
              label: Text(AppTranslations.tr(ref, 'restore')),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
            )),
            const SizedBox(width: 8),
            Expanded(
                child: FilledButton.icon(
              onPressed: () => _confirmDelete(post.id),
              icon: const Icon(CupertinoIcons.delete, size: 18),
              label: const Text('Xóa ngay'),
              style: FilledButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFFDC2626),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _thumbnail(ThemeData theme, PostModel post) => Stack(children: [
        AspectRatio(
          aspectRatio: 2.15,
          child: kIsWeb
              ? Image.network(
                  post.media.first.thumbnailUrl ?? post.media.first.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(CupertinoIcons.photo,
                          color: theme.colorScheme.onSurfaceVariant)),
                  loadingBuilder: (_, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const CupertinoActivityIndicator());
                  },
                )
              : CachedNetworkImage(
                  imageUrl: post.media.first.thumbnailUrl ?? post.media.first.url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const CupertinoActivityIndicator()),
                  errorWidget: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(CupertinoIcons.photo,
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
        ),
        if (post.media.length > 1)
          Positioned(
            right: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .62),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(CupertinoIcons.photo_on_rectangle,
                    color: Colors.white, size: 13),
                const SizedBox(width: 4),
                Text('${post.media.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
      ]);

  Widget _countdownBadge(ThemeData theme, Duration? remaining, bool urgent) {
    final color = urgent ? theme.colorScheme.error : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(_formatRemaining(remaining),
          style: theme.textTheme.labelMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w800)),
    );
  }

  String _formatRemaining(Duration? remaining) {
    if (remaining == null) return 'Không rõ hạn';
    if (remaining <= Duration.zero) return 'Đã hết hạn';
    if (remaining < const Duration(hours: 1)) {
      return 'Còn ${remaining.inMinutes.clamp(1, 59)} phút';
    }
    if (remaining < const Duration(days: 1)) {
      return 'Còn ${remaining.inHours} giờ';
    }
    return 'Còn ${(remaining.inSeconds / Duration.secondsPerDay).ceil()} ngày';
  }

  String _formatDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}, ${two(value.day)}/${two(value.month)}/${value.year}';
  }

  Future<void> _restore(String postId) async {
    try {
      await ref.read(postRepositoryProvider).restoreFromTrash(postId);
      ref.read(postLocalStatesProvider.notifier).undo(postId);
      ref.invalidate(trashedPostsProvider);
      ref.invalidate(feedPostsProvider);
      if (mounted) {
        ToastService.showSuccess(context, 'Đã khôi phục bài viết.');
      }
    } catch (error) {
      if (mounted) {
        ToastService.showError(context, 'Không thể khôi phục: $error');
      }
    }
  }

  void _confirmDelete(String postId) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Xóa vĩnh viễn bài viết?'),
        content: const Text(
            'Ảnh, nội dung và dữ liệu liên quan sẽ bị xóa ngay. Bạn không thể hoàn tác thao tác này.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => dialogContext.pop(),
            child: const Text('Giữ lại'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              dialogContext.pop();
              await _deletePermanently(postId);
            },
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePermanently(String postId) async {
    try {
      await ref.read(postRepositoryProvider).deletePost(postId);
      ref.invalidate(trashedPostsProvider);
      ref.invalidate(feedPostsProvider);
      if (mounted) {
        ToastService.showSuccess(context, 'Đã xóa vĩnh viễn bài viết.');
      }
    } catch (error) {
      if (mounted) {
        ToastService.showError(context, 'Không thể xóa bài viết: $error');
      }
    }
  }
}
