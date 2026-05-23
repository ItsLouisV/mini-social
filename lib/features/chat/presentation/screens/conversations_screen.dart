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
import '../../providers/hidden_chat_provider.dart';
import '../widgets/new_message_modal.dart';
import '../widgets/passcode_dialog.dart';

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
              final convs = ref.read(conversationsProvider).valueOrNull ?? [];
              final currentUserId = ref.read(currentUserIdProvider);
              final hiddenCount = currentUserId == null ? 0 : convs.where((c) => c.isHidden(currentUserId)).length;

              if (hiddenCount == 0) {
                // Xoá passcode cũ vì không còn cuộc trò chuyện ẩn nào
                await ref.read(hiddenChatProvider.notifier).removePasscode();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chưa có cuộc trò chuyện nào bị ẩn')),
                  );
                }
              } else {
                final success = await PasscodeDialog.show(context, mode: PasscodeMode.verify);
                if (success == true && context.mounted) {
                  context.push('/chat/hidden');
                }
              }
            },
            icon: Icon(
              CupertinoIcons.eye_slash,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
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
            if (currentUserId != null && c.isHidden(currentUserId)) return false;
            final name = c.otherUser?.displayName.toLowerCase() ?? '';
            final username = c.otherUser?.username.toLowerCase() ?? '';
            return name.contains(_searchQuery.toLowerCase()) ||
                username.contains(_searchQuery.toLowerCase());
          }).toList();

          // Sắp xếp: Pinned lên trên
          if (currentUserId != null) {
            filteredConvs.sort((a, b) {
              final aPinned = a.isPinned(currentUserId) ? 1 : 0;
              final bPinned = b.isPinned(currentUserId) ? 1 : 0;
              if (aPinned != bPinned) return bPinned.compareTo(aPinned);
              // Fallback to lastMessageAt
              final aTime = a.lastMessageAt ?? a.createdAt;
              final bTime = b.lastMessageAt ?? b.createdAt;
              return bTime.compareTo(aTime);
            });
          }

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
                    : SlidableAutoCloseBehavior(
                        child: ListView.separated(
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

class _ConversationTile extends ConsumerWidget {
  final ConversationModel conv;
  final String? currentUserId;
  final VoidCallback onTap;

  const _ConversationTile({
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
      // Vuốt từ Trái -> Phải: Ghim / Bỏ ghim với StretchMotion & ExtentRatio
      startActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.22,
        children: [
          CustomSlidableAction(
            onPressed: (context) {
              HapticFeedback.lightImpact();
              ref.read(chatRepositoryProvider).togglePin(conv);
            },
            backgroundColor: Colors.transparent,
            child: Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF), // Blue iOS
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.15),
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
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        conv.isPinned(currentUserId ?? '') 
                            ? CupertinoIcons.pin_slash_fill 
                            : CupertinoIcons.pin_fill,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        conv.isPinned(currentUserId ?? '') ? 'Bỏ ghim' : 'Ghim',
                        style: const TextStyle(
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
      // Vuốt từ Phải -> Trái: Ẩn và Xoá với StretchMotion & ExtentRatio
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.44,
        children: [
          CustomSlidableAction(
            onPressed: (context) async {
              HapticFeedback.lightImpact();
              final convs = ref.read(conversationsProvider).valueOrNull ?? [];
              final hiddenCount = currentUserId == null ? 0 : convs.where((c) => c.isHidden(currentUserId!)).length;

              if (hiddenCount == 0) {
                // Reset mã pin vì chưa có ai bị ẩn
                await ref.read(hiddenChatProvider.notifier).removePasscode();
                if (!context.mounted) return;
                
                final success = await PasscodeDialog.show(context, mode: PasscodeMode.setup);
                if (success == true) {
                  ref.read(chatRepositoryProvider).toggleHide(conv);
                }
              } else {
                // Đã có hội thoại ẩn, tự động ẩn luôn
                ref.read(chatRepositoryProvider).toggleHide(conv);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã chuyển vào cuộc trò chuyện bị ẩn')),
                  );
                }
              }
            },
            backgroundColor: Colors.transparent,
            child: Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8E8E93), // Gray
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8E8E93).withValues(alpha: 0.15),
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
                      Icon(CupertinoIcons.eye_slash_fill, color: Colors.white, size: 20),
                      SizedBox(height: 4),
                      Text(
                        'Ẩn',
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
        color: conv.isPinned(currentUserId ?? '') 
            ? (isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF2F2F7)) 
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
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
                          ),
                          if (conv.isPinned(currentUserId ?? ''))
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                CupertinoIcons.pin_fill,
                                size: 12,
                                color: hintColor,
                              ),
                            ),
                        ],
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
      ),
    );
  }
}
