import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/extensions/date_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../social/providers/follow_provider.dart';
import '../../../auth/providers/auth_provider.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                icon: const Icon(CupertinoIcons.checkmark_circle, size: 24),
                tooltip: 'Đánh dấu đã đọc',
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
                      return _NotificationTile(notification: n);
                    },
                    childCount: notifications.length,
                  ),
                ),
              );
            },
            loading: () => SliverFillRemaining(
              child: _buildShimmer(context, isDark),
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

  Widget _buildShimmer(BuildContext context, bool isDark) {
    final baseColor = isDark ? const Color(0xFF262635) : const Color(0xFFEBEBF0);
    
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: baseColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 150,
                    height: 14,
                    decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4)),
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
        'Người dùng';
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
                      // More options
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
