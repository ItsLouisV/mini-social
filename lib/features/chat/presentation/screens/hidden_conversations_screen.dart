import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

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

          return ListView.separated(
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
      // Vuốt từ Trái -> Phải: Bỏ ẩn
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              ref.read(chatRepositoryProvider).toggleHide(conv);
            },
            backgroundColor: const Color(0xFF34C759), // Green iOS
            foregroundColor: Colors.white,
            icon: CupertinoIcons.eye_fill,
            label: 'Bỏ ẩn',
          ),
        ],
      ),
      // Vuốt từ Phải -> Trái: Xoá
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
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
                        Navigator.pop(ctx);
                        ref.read(chatRepositoryProvider).deleteConversation(conv.id);
                      },
                      child: const Text('Xoá'),
                    ),
                  ],
                ),
              );
            },
            backgroundColor: const Color(0xFFFF3B30), // Red iOS
            foregroundColor: Colors.white,
            icon: CupertinoIcons.delete_solid,
            label: 'Xoá',
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
              backgroundImage: conv.otherUser?.avatarUrl != null
                  ? NetworkImage(conv.otherUser!.avatarUrl!)
                  : null,
              child: conv.otherUser?.avatarUrl == null
                  ? const Icon(CupertinoIcons.person_fill, color: Colors.white)
                  : null,
            ),
          ],
        ),
        title: Text(
          conv.otherUser?.displayName ?? 'Người dùng',
          style: TextStyle(
            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
            color: titleColor,
          ),
        ),
        subtitle: Text(
          conv.lastMessage ?? 'Chưa có tin nhắn',
          style: TextStyle(
            color: hasUnread ? theme.colorScheme.onSurface : hintColor,
            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
