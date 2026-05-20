import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/date_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/conversation_model.dart';
import '../../providers/chat_provider.dart';
import '../widgets/new_message_modal.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final convAsync = ref.watch(conversationsProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: Text(
          'Tin nhắn',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
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
            icon: Icon(
              CupertinoIcons.square_pencil,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 4),
        ],
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
          final filteredConvs = conversations.where((c) {
            final name = c.otherUser?.displayName.toLowerCase() ?? '';
            final username = c.otherUser?.username.toLowerCase() ?? '';
            return name.contains(_searchQuery.toLowerCase()) ||
                username.contains(_searchQuery.toLowerCase());
          }).toList();

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: 'Tìm kiếm',
                  style:
                      TextStyle(color: theme.textTheme.bodyLarge?.color),
                  placeholderStyle: TextStyle(color: theme.hintColor),
                  backgroundColor: theme.brightness == Brightness.dark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFF767680).withValues(alpha: 0.12),
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.trim()),
                ),
              ),

              // Conversation list
              Expanded(
                child: filteredConvs.isEmpty
                    ? Center(
                        child: EmptyStateWidget(
                          icon: CupertinoIcons.chat_bubble_2,
                          title: _searchQuery.isEmpty
                              ? 'Chưa có cuộc trò chuyện nào'
                              : 'Không tìm thấy kết quả',
                          subtitle: _searchQuery.isEmpty
                              ? 'Nhắn tin với bạn bè từ trang hồ sơ của họ'
                              : 'Thử tìm kiếm với tên hiển thị khác',
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredConvs.length,
                        separatorBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(left: 76),
                          child: Divider(
                            height: 0.5,
                            thickness: 0.5,
                            color:
                                theme.dividerColor.withValues(alpha: 0.25),
                          ),
                        ),
                        itemBuilder: (context, index) {
                          final conv = filteredConvs[index];
                          return _ConversationTile(
                            conv: conv,
                            currentUserId: currentUserId,
                            onTap: () =>
                                context.push('/chat/${conv.id}'),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () =>
            const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(conversationsProvider),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationModel conv;
  final String? currentUserId;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conv,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasUnread = conv.lastMessageSenderId != currentUserId &&
        conv.lastMessage != null;
    final titleColor = theme.textTheme.titleMedium?.color;
    final hintColor = theme.hintColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Unread dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: hasUnread ? 8 : 0),
                width: hasUnread ? 8 : 0,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF007AFF),
                  shape: BoxShape.circle,
                ),
              ),

              // Avatar
              AppAvatar(
                imageUrl: conv.otherUser?.avatarUrl,
                name: conv.otherUser?.displayName,
                radius: 28,
              ),
              const SizedBox(width: 14),

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
                          : 'Bắt đầu cuộc trò chuyện',
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
    );
  }
}
