import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/extensions/date_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/parsed_caption_text.dart';
import '../../../profile/providers/profile_provider.dart';
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
    final localStates = ref.watch(postLocalStatesProvider);
    final status = localStates[post.id] ?? PostLocalStatus.none;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (status == PostLocalStatus.dismissed) {
      return const SizedBox.shrink();
    }

    if (status == PostLocalStatus.snoozed || status == PostLocalStatus.hidden) {
      return _HiddenPostBanner(
        post: post,
        ref: ref,
        message: 'Bạn sẽ không nhìn thấy bài viết của ${post.author?.displayName ?? 'người này'} trên Bảng feed trong 30 ngày.',
        showFeedbackPills: true,
        onUndo: () async {
          try {
            await ref.read(profileRepositoryProvider).unmuteUser(post.userId);
            ref.read(postLocalStatesProvider.notifier).undo(post.id);
            ref.invalidate(feedPostsProvider);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi hoàn tác: $e')),
              );
            }
          }
        },
      );
    }

    if (status == PostLocalStatus.reported) {
      return _HiddenPostBanner(
        post: post,
        ref: ref,
        message: 'Đã báo cáo bài viết. Cảm ơn bạn đã đóng góp ý kiến.',
        showFeedbackPills: false,
        onUndo: () async {
          try {
            await ref.read(postRepositoryProvider).cancelReportPost(post.id);
            ref.read(postLocalStatesProvider.notifier).undo(post.id);
            ref.invalidate(feedPostsProvider);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi hoàn tác báo cáo: $e')),
              );
            }
          }
        },
      );
    }

    if (status == PostLocalStatus.trashed) {
      return _HiddenPostBanner(
        post: post,
        ref: ref,
        message: 'Đã chuyển bài viết vào thùng rác. Các mục trong thùng rác sẽ bị xóa sau 30 ngày.',
        showFeedbackPills: false,
        onUndo: () async {
          try {
            await ref.read(postRepositoryProvider).restoreFromTrash(post.id);
            ref.read(postLocalStatesProvider.notifier).undo(post.id);
            ref.invalidate(feedPostsProvider);
            ref.invalidate(trashedPostsProvider);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi khôi phục bài viết: $e')),
              );
            }
          }
        },
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: isDark ? 0.05 : 0.08), width: 0.5),
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: isDark ? 0.05 : 0.08), width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Meta, More/Close
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                AppAvatar(
                  imageUrl: post.author?.avatarUrl,
                  name: post.author?.displayName,
                  radius: 20,
                  onTap: () => context.push('/profile/${post.userId}'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/profile/${post.userId}'),
                        child: Text(
                          post.author?.displayName ?? 'Unknown',
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            post.createdAt.timeAgo,
                            style: AppTextStyles.caption.copyWith(
                              color: Theme.of(context).hintColor,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '•',
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            _getPrivacyIcon(post.privacy),
                            size: 11,
                            color: Theme.of(context).hintColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showMoreOptions(context, ref, isOwner),
                  child: const Icon(CupertinoIcons.ellipsis, size: 18),
                ),
                if (!isOwner) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () async {
                      try {
                        await ref.read(profileRepositoryProvider).muteUser(post.userId);
                        ref.read(postLocalStatesProvider.notifier).snoozePost(post.id);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi tạm ẩn bài viết: $e')),
                          );
                        }
                      }
                    },
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 16,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Caption Text (Tự động highlight #hashtag & @username)
          if (post.caption?.isNotEmpty == true) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ParsedCaptionText(
                text: post.caption!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Media (full width, flush to edge)
          if (post.media.isNotEmpty)
            ImageCarousel(
              media: post.media,
              layoutType: post.layoutType,
            ),

          // PostActions (Facebook layout)
          PostActions(
            post: post,
            onCommentTap: () => context.push('/feed/post/${post.id}'),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context, WidgetRef ref, bool isOwner) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _FacebookOptionsBottomSheet(
          post: post,
          ref: ref,
          isOwner: isOwner,
        );
      },
    );
  }

  void _showReportDialog(BuildContext context, WidgetRef ref) {
    _showGlobalReportDialog(context, ref, post);
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
                ref.invalidate(feedPostsProvider);
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

// ── Multi-page Bottom Sheet kiểu Facebook ──
class _FacebookOptionsBottomSheet extends StatefulWidget {
  final PostModel post;
  final WidgetRef ref;
  final bool isOwner;

  const _FacebookOptionsBottomSheet({
    required this.post,
    required this.ref,
    required this.isOwner,
  });

  @override
  State<_FacebookOptionsBottomSheet> createState() => _FacebookOptionsBottomSheetState();
}

class _FacebookOptionsBottomSheetState extends State<_FacebookOptionsBottomSheet> {
  int _currentPage = 0; // 0: Main Menu, 1: Lựa chọn khác

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 8,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: _currentPage == 0 ? _buildMainMenu(context) : _buildOtherOptions(context),
      ),
    );
  }

  Widget _buildDragHandle(ThemeData theme) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.hintColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildMainMenu(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDragHandle(theme),
        if (widget.isOwner) ...[
          _buildOptionTile(
            icon: CupertinoIcons.pencil,
            title: 'Chỉnh sửa bài viết',
            onTap: () {
              Navigator.pop(context);
              _showEditCaptionDialog(context, widget.ref, widget.post);
            },
          ),
          const Divider(height: 1),
          _buildOptionTile(
            icon: CupertinoIcons.trash,
            title: 'Chuyển vào thùng rác',
            subtitle: 'Các mục trong thùng rác sẽ bị xóa sau 30 ngày',
            titleColor: Colors.red,
            iconColor: Colors.red,
            onTap: () {
              Navigator.pop(context);
              _confirmMoveToTrash(context, widget.ref, widget.post);
            },
          ),
        ] else ...[
          _buildOptionTile(
            icon: CupertinoIcons.plus_circle,
            title: 'Quan tâm',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã thêm vào danh sách quan tâm')),
              );
            },
          ),
          _buildOptionTile(
            icon: CupertinoIcons.minus_circle,
            title: 'Không quan tâm',
            subtitle: 'Ẩn bớt các bài viết tương tự',
            onTap: () async {
              Navigator.pop(context);
              try {
                await widget.ref.read(profileRepositoryProvider).muteUser(widget.post.userId);
                widget.ref.read(postLocalStatesProvider.notifier).snoozePost(widget.post.id);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi ẩn bài viết: $e')),
                );
              }
            },
          ),
          const Divider(height: 1),
          _buildOptionTile(
            icon: CupertinoIcons.bookmark,
            title: 'Lưu bài viết',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã lưu bài viết')),
              );
            },
          ),
          _buildOptionTile(
            icon: CupertinoIcons.exclamationmark_bubble,
            title: 'Báo cáo bài viết',
            onTap: () {
              Navigator.pop(context);
              _showGlobalReportDialog(context, widget.ref, widget.post);
            },
          ),
          _buildOptionTile(
            icon: CupertinoIcons.ellipsis_circle,
            title: 'Lựa chọn khác',
            trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
            onTap: () {
              setState(() => _currentPage = 1);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildOtherOptions(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = widget.post.author?.displayName ?? 'người này';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDragHandle(theme),
        Row(
          children: [
            IconButton(
              icon: const Icon(CupertinoIcons.left_chevron, size: 16),
              onPressed: () => setState(() => _currentPage = 0),
            ),
            const Text(
              'Lựa chọn khác',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildOptionTile(
          icon: CupertinoIcons.time,
          title: 'Tạm ẩn $displayName trong 30 ngày',
          onTap: () async {
            Navigator.pop(context);
            try {
              await widget.ref.read(profileRepositoryProvider).muteUser(widget.post.userId);
              widget.ref.read(postLocalStatesProvider.notifier).snoozePost(widget.post.id);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi tạm ẩn: $e')),
              );
            }
          },
        ),
        _buildOptionTile(
          icon: CupertinoIcons.info_circle,
          title: 'Tại sao tôi nhìn thấy bài viết này?',
          onTap: () {
            Navigator.pop(context);
            _showWhySeeThisPostDialog(context, widget.post);
          },
        ),
        _buildOptionTile(
          icon: CupertinoIcons.bell,
          title: 'Nhận thông báo về bài viết này',
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã bật nhận thông báo cho bài viết này')),
            );
          },
        ),
        _buildOptionTile(
          icon: CupertinoIcons.slider_horizontal_3,
          title: 'Tùy chọn nội dung',
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã cập nhật tuỳ chọn nội dung')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Color? iconColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: iconColor ?? theme.iconTheme.color),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: titleColor ?? theme.textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

// ── Dialog Chỉnh sửa bài viết ──
void _showEditCaptionDialog(BuildContext context, WidgetRef ref, PostModel post) {
  final controller = TextEditingController(text: post.caption);
  showDialog(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        title: const Text('Chỉnh sửa bài viết', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Nhập nội dung mới...',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newCaption = controller.text.trim();
              Navigator.pop(context);
              try {
                await ref.read(postRepositoryProvider).updatePostCaption(post.id, newCaption);
                ref.invalidate(feedPostsProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi cập nhật: $e')),
                  );
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      );
    },
  );
}

// ── Xác nhận chuyển vào thùng rác ──
void _confirmMoveToTrash(BuildContext context, WidgetRef ref, PostModel post) {
  showCupertinoDialog(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Chuyển vào thùng rác?'),
      content: const Text('Bài viết sẽ biến mất khỏi bảng tin. Các mục trong thùng rác sẽ bị xóa sau 30 ngày.'),
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
              await ref.read(postRepositoryProvider).moveToTrash(post.id);
              ref.read(postLocalStatesProvider.notifier).trashPost(post.id);
              ref.invalidate(trashedPostsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Đã chuyển bài viết vào thùng rác.'),
                    action: SnackBarAction(
                      label: 'Xem Thùng rác',
                      onPressed: () => context.push('/trash'),
                    ),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Thao tác thất bại: $e')),
                );
              }
            }
          },
          child: const Text('Chuyển'),
        ),
      ],
    ),
  );
}

// ── Dialog giải thích tại sao xem bài viết ──
void _showWhySeeThisPostDialog(BuildContext context, PostModel post) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Tại sao tôi nhìn thấy bài viết này?'),
        content: Text(
          '• Bài viết này được cài đặt chế độ là "${post.privacy == 'public' ? 'Công khai' : 'Bạn bè/Follower'}".\n\n'
          '• Bạn đang theo dõi ${post.author?.displayName ?? 'tác giả này'} hoặc bài viết được chia sẻ công khai trên MiniSocial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      );
    },
  );
}

// ── Dialog Báo cáo bài viết toàn cục ──
void _showGlobalReportDialog(BuildContext context, WidgetRef ref, PostModel post) {
  final Set<String> selectedReasons = {};
  final customReasonController = TextEditingController();

  final options = [
    'Spam',
    'Bạo lực hoặc nội dung phản cảm',
    'Quấy rối',
    'Ngôn từ gây thù ghét',
    'Tin giả/Sai sự thật',
    'Khác...',
  ];

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;

          final hasCustomText = selectedReasons.contains('Khác...') &&
              customReasonController.text.trim().isNotEmpty;

          final canSubmit = selectedReasons.isNotEmpty &&
              (!selectedReasons.contains('Khác...') || hasCustomText || selectedReasons.length > 1);

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: theme.dialogBackgroundColor,
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Row(
              children: [
                Icon(
                  CupertinoIcons.flag_fill,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Báo cáo bài viết',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hãy chọn một hoặc nhiều lý do bạn muốn báo cáo:',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...options.map((reason) {
                    final isChecked = selectedReasons.contains(reason);
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isChecked) {
                            selectedReasons.remove(reason);
                          } else {
                            selectedReasons.add(reason);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isChecked
                                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                                : theme.dividerColor.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isChecked
                                  ? CupertinoIcons.checkmark_square_fill
                                  : CupertinoIcons.square,
                              color: isChecked
                                  ? theme.colorScheme.primary
                                  : theme.hintColor,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                reason,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                                  color: isChecked
                                      ? theme.colorScheme.primary
                                      : theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (selectedReasons.contains('Khác...')) ...[
                    const SizedBox(height: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : theme.colorScheme.surfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: TextField(
                        controller: customReasonController,
                        onChanged: (_) => setState(() {}),
                        maxLines: 3,
                        minLines: 2,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Nhập chi tiết lý do của bạn...',
                          hintStyle: TextStyle(fontSize: 13, color: theme.hintColor),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: theme.hintColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('Hủy'),
              ),
              if (canSubmit)
                ElevatedButton(
                  onPressed: () async {
                    final List<String> resultReasons = [];
                    for (final r in options) {
                      if (selectedReasons.contains(r)) {
                        if (r == 'Khác...') {
                          final customText = customReasonController.text.trim();
                          if (customText.isNotEmpty) {
                            resultReasons.add('Khác: $customText');
                          } else if (selectedReasons.length == 1) {
                            resultReasons.add('Lý do khác');
                          }
                        } else {
                          resultReasons.add(r);
                        }
                      }
                    }

                    final finalReasonStr = resultReasons.join(', ');
                    Navigator.pop(context);

                    try {
                      await ref.read(postRepositoryProvider).reportPost(
                            postId: post.id,
                            reason: finalReasonStr,
                          );
                      ref.read(postLocalStatesProvider.notifier).reportPost(post.id);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi gửi báo cáo: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text(
                    'Gửi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}

// ── Banner Ẩn / Báo cáo / Thùng rác bài viết ──
class _HiddenPostBanner extends StatefulWidget {
  final PostModel post;
  final WidgetRef ref;
  final String message;
  final VoidCallback onUndo;
  final bool showFeedbackPills;

  const _HiddenPostBanner({
    required this.post,
    required this.ref,
    required this.message,
    required this.onUndo,
    this.showFeedbackPills = false,
  });

  @override
  State<_HiddenPostBanner> createState() => _HiddenPostBannerState();
}

class _HiddenPostBannerState extends State<_HiddenPostBanner> {
  final Set<String> _selectedFeedbackReasons = {};
  bool _isSubmitting = false;

  @override
  void dispose() {
    final ref = widget.ref;
    final postId = widget.post.id;
    final currentState = ref.read(postLocalStatesProvider)[postId];
    if (currentState != null && currentState != PostLocalStatus.none) {
      Future.microtask(() {
        ref.read(postLocalStatesProvider.notifier).dismissPost(postId);
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: Key('dismiss_${widget.post.id}'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) {
        widget.ref.read(postLocalStatesProvider.notifier).dismissPost(widget.post.id);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.eye_slash_fill, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  AppTranslations.tr(widget.ref, 'hidden_post'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onUndo,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    AppTranslations.tr(widget.ref, 'undo'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color,
                height: 1.3,
              ),
            ),
            if (widget.showFeedbackPills) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                AppTranslations.tr(widget.ref, 'why_not_interested'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFeedbackPill('Không phù hợp với các mối quan tâm của tôi'),
                  _buildFeedbackPill('Lừa đảo'),
                  _buildFeedbackPill('Tình dục'),
                  _buildFeedbackPill('Gây phiền toái'),
                  _buildFeedbackPill('Tôi không thích người sáng tạo nội dung này'),
                  _buildFeedbackPill(AppTranslations.tr(widget.ref, 'other'), isOther: true),
                ],
              ),
              if (_selectedFeedbackReasons.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            setState(() => _isSubmitting = true);
                            try {
                              final finalReasonStr = _selectedFeedbackReasons.join(', ');
                              await widget.ref.read(postRepositoryProvider).reportPost(
                                    postId: widget.post.id,
                                    reason: finalReasonStr,
                                  );
                              widget.ref
                                  .read(postLocalStatesProvider.notifier)
                                  .reportPost(widget.post.id);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Lỗi gửi báo cáo: $e')),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _isSubmitting = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            AppTranslations.tr(widget.ref, 'send'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackPill(String text, {bool isOther = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _selectedFeedbackReasons.contains(text);

    return InkWell(
      onTap: () async {
        if (isOther) {
          _showGlobalReportDialog(context, widget.ref, widget.post);
        } else {
          setState(() {
            if (isSelected) {
              _selectedFeedbackReasons.remove(text);
            } else {
              _selectedFeedbackReasons.add(text);
            }
          });
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.12)
              : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}
