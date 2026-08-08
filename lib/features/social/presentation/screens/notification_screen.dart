import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/extensions/date_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../social/providers/follow_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../shared/widgets/skeletons/tile_skeleton_loading.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            pinned: true,
            centerTitle: false,
            title: Text(AppTranslations.tr(ref, 'notifications'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            actions: [
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.listCheck, size: 20),
                tooltip: 'Đọc tất cả.',
                onPressed: () {
                  ref.read(socialRepositoryProvider).markAllAsRead().then((_) {
                    ref.invalidate(notificationsProvider);
                  });
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          notificationsAsync.when(
            data: (notifications) {
              if (notifications.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateWidget(
                    icon: CupertinoIcons.bell,
                    title: 'Chưa có thông báo',
                    subtitle: 'Khi có người tương tác với bạn, thông báo sẽ hiện ở đây.',
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final n = notifications[index];
                      final notifId = n['id']?.toString() ?? 'notif_$index';
                      return Dismissible(
                        key: Key(notifId),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.redAccent,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.trash_fill, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Xóa',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        onDismissed: (direction) {
                          final id = n['id'] as String?;
                          if (id != null) {
                            HapticFeedback.mediumImpact();
                            ref.read(socialRepositoryProvider).deleteNotification(id).then((_) {
                              ref.invalidate(notificationsProvider);
                            });
                          }
                        },
                        child: _NotificationTile(notification: n),
                      );
                    },
                    childCount: notifications.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: TileSkeletonLoading(hasSearchBar: false, itemCount: 8),
            ),
            error: (e, _) => SliverFillRemaining(
              child: AppErrorWidget(
                message: e.toString(),
                onRetry: () => ref.invalidate(notificationsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final Map<String, dynamic> notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final type = notification['type'] as String?;
    final isRead = notification['is_read'] as bool? ?? true;
    final createdAt = notification['created_at'] != null
        ? DateTime.parse(notification['created_at'] as String)
        : DateTime.now();

    final sender = notification['profiles'] as Map<String, dynamic>?;
    final senderName = sender?['full_name'] as String? ??
        sender?['username'] as String? ??
        notification['sender_name'] as String? ??
        (type == 'moderation' ? 'Hệ thống' : 'Người dùng');
    final senderAvatar = sender?['avatar_url'] as String?;

    String actionText = '';
    IconData icon = CupertinoIcons.bell_fill;
    Color iconColor = theme.colorScheme.primary;

    switch (type) {
      case 'like':
        actionText = ' đã thích bài viết của bạn';
        icon = CupertinoIcons.heart_fill;
        iconColor = const Color(0xFFFC2A35);
        break;
      case 'comment':
        actionText = ' đã bình luận về bài viết của bạn';
        icon = CupertinoIcons.chat_bubble_fill;
        iconColor = const Color(0xFF007AFF);
        break;
      case 'reply':
        actionText = ' đã trả lời bình luận của bạn';
        icon = CupertinoIcons.chat_bubble_2_fill;
        iconColor = const Color(0xFF007AFF);
        break;
      case 'follow':
        actionText = ' đã bắt đầu theo dõi bạn';
        icon = CupertinoIcons.person_add_solid;
        iconColor = const Color(0xFF34C759);
        break;
      case 'friend_request':
        actionText = ' đã gửi lời mời kết bạn cho bạn';
        icon = CupertinoIcons.person_add_solid;
        iconColor = const Color(0xFF007AFF);
        break;
      case 'friend_accept':
        actionText = ' đã chấp nhận lời mời kết bạn của bạn';
        icon = CupertinoIcons.person_2_fill;
        iconColor = const Color(0xFF34C759);
        break;
      case 'moderation':
        actionText = ' đã gửi quyết định kiểm duyệt';
        icon = CupertinoIcons.exclamationmark_triangle_fill;
        iconColor = const Color(0xFFFF9500);
        break;
      case 'group_dissolved':
        actionText = ' đã giải tán nhóm';
        icon = CupertinoIcons.person_3_fill;
        iconColor = const Color(0xFFFF3B30);
        break;
      case 'group_added':
        actionText = ' đã thêm bạn vào nhóm';
        icon = CupertinoIcons.person_3_fill;
        iconColor = const Color(0xFF5856D6);
        break;
      default:
        actionText = ' có một thông báo mới';
    }

    final bgColor = isRead 
        ? Colors.transparent 
        : (isDark ? const Color(0xFF1B2642) : const Color(0xFFE5EFFF));

    final postId = notification['post_id'] as String?;
    final senderId = notification['sender_id'] as String?;

    return Material(
      color: bgColor,
      child: InkWell(
        onTap: () {
          // Mark as read on tap if unread
          if (!isRead) {
            final notifId = notification['id'] as String?;
            if (notifId != null) {
              ref.read(socialRepositoryProvider).markNotificationAsRead(notifId).then((_) {
                ref.invalidate(notificationsProvider);
              });
            }
          }
          switch (type) {
            case 'like':
            case 'comment':
            case 'reply':
              if (postId != null) {
                context.push('/feed/post/$postId');
              }
              break;
            case 'follow':
            case 'friend_accept':
              if (senderId != null) {
                context.push('/profile/$senderId');
              }
              break;
            case 'friend_request':
              final myId = ref.read(currentUserIdProvider);
              if (myId != null) {
                context.push('/profile/$myId/friends?tab=pending');
              }
              break;
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar & Icon Badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(imageUrl: senderAvatar, name: senderName, radius: 24),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: iconColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isRead ? theme.scaffoldBackgroundColor : bgColor,
                          width: 2,
                        ),
                      ),
                      child: Icon(icon, size: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          height: 1.4,
                          color: isRead ? theme.textTheme.bodyMedium?.color : theme.textTheme.titleLarge?.color,
                        ),
                        children: [
                          TextSpan(
                            text: senderName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: actionText),
                        ],
                      ),
                    ),
                    if (notification['content'] != null && notification['content'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '"${notification['content']}"',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isRead ? theme.hintColor : theme.textTheme.bodyMedium?.color,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      createdAt.timeAgo,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                        color: isRead ? theme.hintColor : theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Trailing Actions (More menu + Unread Dot)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      final notifId = notification['id'] as String?;
                      if (notifId == null) return;
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) {
                          return Container(
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.dark
                                  ? const Color(0xFF1E1E2F)
                                  : Colors.white,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(CupertinoIcons.trash, color: Colors.redAccent),
                                    title: const Text('Xóa thông báo này', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      HapticFeedback.mediumImpact();
                                      ref.read(socialRepositoryProvider).deleteNotification(notifId).then((_) {
                                        ref.invalidate(notificationsProvider);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Icon(CupertinoIcons.ellipsis, size: 20, color: theme.hintColor),
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
