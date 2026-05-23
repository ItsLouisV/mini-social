import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../core/extensions/date_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/conversation_model.dart';
import '../../providers/chat_provider.dart';

class HiddenConversationsScreen extends ConsumerWidget {
  const HiddenConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convAsync = ref.watch(conversationsProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_back, color: theme.colorScheme.primary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Đoạn chat bị ẩn',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(
            height: 0.5,
            thickness: 0.5,
            color: theme.dividerColor.withValues(alpha: 0.25),
          ),
        ),
      ),
      body: convAsync.when(
        data: (conversations) {
          // Lọc danh sách ĐÃ BỊ ẨN
          final filteredConvs = conversations.where((c) {
            return currentUserId != null && c.isHidden(currentUserId);
          }).toList();

          filteredConvs.sort((a, b) {
            final aTime = a.lastMessageAt ?? a.createdAt;
            final bTime = b.lastMessageAt ?? b.createdAt;
            return bTime.compareTo(aTime);
          });

          if (filteredConvs.isEmpty) {
            return Center(
              child: EmptyStateWidget(
                icon: CupertinoIcons.eye_slash,
                title: 'Không có tin nhắn ẩn',
                subtitle: 'Các cuộc trò chuyện bị ẩn sẽ xuất hiện ở đây',
              ),
            );
          }

          return SlidableAutoCloseBehavior(
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 8),
              itemCount: filteredConvs.length,
              separatorBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(left: 76),
                child: Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: theme.dividerColor.withValues(alpha: 0.25),
                ),
              ),
              itemBuilder: (context, index) {
                final conv = filteredConvs[index];
                return _HiddenConversationTile(
                  conv: conv,
                  currentUserId: currentUserId,
                  onTap: () => context.push('/chat/${conv.id}'),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(conversationsProvider),
        ),
      ),
    );
  }
}

class _HiddenConversationTile extends ConsumerWidget {
  final ConversationModel conv;
  final String? currentUserId;
  final VoidCallback onTap;

  const _HiddenConversationTile({
    required this.conv,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final hasUnread = (currentUserId != null) && (conv.getUnreadCount(currentUserId!) > 0);
    final titleColor = theme.textTheme.titleMedium?.color;
    final hintColor = theme.hintColor;

    return Slidable(
      key: ValueKey(conv.id),
      // Vuốt từ Trái -> Phải: Bỏ ẩn với StretchMotion & ExtentRatio
      startActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.22,
        children: [
          CustomSlidableAction(
            onPressed: (context) {
              HapticFeedback.lightImpact();
              ref.read(chatRepositoryProvider).toggleHide(conv);
            },
            backgroundColor: Colors.transparent,
            child: Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759), // Green iOS
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF34C759).withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 50 || constraints.maxHeight < 40) {
                    return const SizedBox.shrink();
                  }
                  return const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.eye_fill, color: Colors.white, size: 20),
                      SizedBox(height: 4),
                      Text(
                        'Bỏ ẩn',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                }
              ),
            ),
          ),
        ],
      ),
      // Vuốt từ Phải -> Trái: Xoá với StretchMotion & ExtentRatio
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.22,
        children: [
          CustomSlidableAction(
            onPressed: (context) {
              HapticFeedback.lightImpact();
              showCupertinoDialog(
                context: context,
                builder: (ctx) => CupertinoAlertDialog(
                  title: const Text('Xoá cuộc trò chuyện?'),
                  content: const Text('Thao tác này sẽ xoá toàn bộ tin nhắn ở cả 2 phía. Bạn có chắc chắn không?'),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text('Huỷ'),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    CupertinoDialogAction(
                      isDestructiveAction: true,
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(ctx);
                        ref.read(chatRepositoryProvider).deleteConversation(conv.id);
                      },
                      child: const Text('Xoá'),
                    ),
                  ],
                ),
              );
            },
            backgroundColor: Colors.transparent,
            child: Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30), // Red iOS
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 50 || constraints.maxHeight < 40) {
                    return const SizedBox.shrink();
                  }
                  return const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.trash_fill, color: Colors.white, size: 20),
                      SizedBox(height: 4),
                      Text(
                        'Xoá',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                }
              ),
            ),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Slim vertical padding for iOS feel
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Unread dot column to prevent avatar shifting layout jumps
                SizedBox(
                  width: 14,
                  child: hasUnread
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF007AFF),
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),

                // Avatar
                AppAvatar(
                  imageUrl: conv.otherUser?.avatarUrl,
                  name: conv.otherUser?.displayName,
                  radius: 25, // Sleek 50px avatar
                ),
                const SizedBox(width: 12),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        conv.otherUser?.displayName ?? 'Người dùng',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: titleColor,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        (conv.lastMessage != null)
                            ? (conv.lastMessageSenderId == currentUserId
                                ? 'Bạn: ${conv.lastMessage}'
                                : conv.lastMessage!)
                            : 'Chưa có tin nhắn',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasUnread
                              ? (isDark ? Colors.white : Colors.black)
                              : hintColor,
                          fontWeight: hasUnread
                              ? FontWeight.w500
                              : FontWeight.w400,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Time & chevron
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      conv.lastMessageAt?.chatTimestamp ?? '',
                      style: TextStyle(
                        color: hasUnread
                            ? const Color(0xFF007AFF)
                            : hintColor,
                        fontSize: 12,
                        fontWeight: hasUnread
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      CupertinoIcons.chevron_forward,
                      size: 14,
                      color: hintColor.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
