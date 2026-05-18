import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../../../core/extensions/date_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../widgets/new_message_modal.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

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
        centerTitle: false,
        title: Text(
          'Tin nhắn',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.square_pencil),
            onPressed: () async {
              final result = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const NewMessageModal(),
              );

              if (result != null && context.mounted) {
                await context.push('/chat/$result');
              }
            },
            color: theme.primaryColor,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: convAsync.when(
        data: (conversations) {
          if (conversations.isEmpty) {
            return const EmptyStateWidget(
              icon: CupertinoIcons.chat_bubble_2,
              title: 'Chưa có cuộc trò chuyện nào',
              subtitle: 'Nhắn tin với bạn bè từ trang hồ sơ của họ',
            );
          }

          return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                return InkWell(
                  onTap: () async {
                    await context.push('/chat/${conv.id}');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar
                        AppAvatar(
                          imageUrl: conv.otherUser?.avatarUrl,
                          name: conv.otherUser?.displayName,
                          radius: 28, // Slightly larger avatar
                        ),
                        const SizedBox(width: 16),
                        
                        // Text Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                conv.otherUser?.displayName ?? 'Unknown',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (conv.lastMessage != null) 
                                    ? (conv.lastMessageSenderId == currentUserId 
                                        ? 'Bạn: ${conv.lastMessage}' 
                                        : conv.lastMessage!) 
                                    : 'Bắt đầu cuộc trò chuyện',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Timestamp and Unread Indicator
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              conv.lastMessageAt?.chatTimestamp ?? '',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.hintColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ],
                    ),
                  ),
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
