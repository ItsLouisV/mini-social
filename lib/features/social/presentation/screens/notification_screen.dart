import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/extensions/date_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../social/providers/follow_provider.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    // Mark all as read when opened
    ref.listen(notificationsProvider, (_, next) {
      next.whenData((_) {
        ref.read(socialRepositoryProvider).markAllAsRead();
      });
    });

    final theme = Theme.of(context);

    return CupertinoPageScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        middle: Text(
          'Thông báo',
          style: TextStyle(
            color: theme.textTheme.titleMedium?.color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SafeArea(
        child: notificationsAsync.when(
          data: (notifications) {
            if (notifications.isEmpty) {
              return const EmptyStateWidget(
                icon: CupertinoIcons.bell,
                title: 'Không có thông báo',
                subtitle: 'Các hoạt động của bạn sẽ hiển thị ở đây',
              );
            }

            return ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = notifications[index];
                return _NotificationTile(notification: n);
              },
            );
          },
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (e, _) => AppErrorWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(notificationsProvider),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final type = notification['type'] as String?;
    final isRead = notification['is_read'] as bool? ?? true;
    final createdAt = notification['created_at'] != null
        ? DateTime.parse(notification['created_at'] as String)
        : DateTime.now();

    final sender = notification['profiles'] as Map<String, dynamic>?;
    final senderName = sender?['full_name'] as String? ??
        sender?['username'] as String? ??
        'Someone';
    final senderAvatar = sender?['avatar_url'] as String?;

    String text = '';
    IconData icon = CupertinoIcons.bell_fill;
    Color iconColor = Theme.of(context).colorScheme.primary;

    switch (type) {
      case 'like':
        text = '$senderName đã thích bài viết của bạn';
        icon = CupertinoIcons.heart_fill;
        iconColor = Colors.red;
        break;
      case 'comment':
        text = '$senderName đã bình luận về bài viết của bạn';
        icon = CupertinoIcons.chat_bubble_fill;
        iconColor = Theme.of(context).colorScheme.primary;
        break;
      case 'follow':
        text = '$senderName đã bắt đầu theo dõi bạn';
        icon = CupertinoIcons.person_add_solid;
        iconColor = Colors.green;
        break;
      default:
        text = 'Thông báo mới';
    }

    return Container(
      color: isRead ? null : Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            AppAvatar(imageUrl: senderAvatar, name: senderName, radius: 22),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.5),
                ),
                child: Icon(icon, size: 10, color: Colors.white),
              ),
            ),
          ],
        ),
        title: Text(text,
            style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: isRead ? FontWeight.w400 : FontWeight.w600)),
        subtitle: Text(createdAt.timeAgo, style: AppTextStyles.caption),
        trailing: isRead
            ? null
            : SizedBox(
                width: 8,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
      ),
    );
  }
}
