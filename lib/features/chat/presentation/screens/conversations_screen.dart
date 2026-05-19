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
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
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
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = theme.scaffoldBackgroundColor;
    final navBarBg = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.92);

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: navBarBg,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        middle: Text(
          'Tin nhắn',
          style: TextStyle(
            color: theme.textTheme.titleMedium?.color,
            fontWeight: FontWeight.w600,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
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
          child: Icon(
            CupertinoIcons.square_pencil,
            color: theme.colorScheme.primary,
            size: 22,
          ),
        ),
      ),
      child: SafeArea(
        child: convAsync.when(
          data: (conversations) {
            // Lọc danh sách theo tìm kiếm
            final filteredConvs = conversations.where((c) {
              final name = c.otherUser?.displayName.toLowerCase() ?? '';
              final username = c.otherUser?.username.toLowerCase() ?? '';
              return name.contains(_searchQuery.toLowerCase()) ||
                  username.contains(_searchQuery.toLowerCase());
            }).toList();

            return Column(
              children: [
                // ── Thanh tìm kiếm iOS ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: 'Tìm kiếm cuộc trò chuyện',
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    placeholderStyle: TextStyle(
                      color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF3C3C43).withValues(alpha: 0.6),
                    ),
                    backgroundColor: isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFF767680).withValues(alpha: 0.12),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                  ),
                ),

                // ── Danh sách bạn bè hoạt động gần đây (Mock Active) ───
                if (conversations.isNotEmpty && _searchQuery.isEmpty)
                  _buildActiveUsersHorizontal(conversations),

                // ── Danh sách cuộc trò chuyện ──────────────────────────
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
                              color: theme.dividerColor.withValues(alpha: 0.25),
                            ),
                          ),
                          itemBuilder: (context, index) {
                            final conv = filteredConvs[index];
                            return _ConversationTile(
                              conv: conv,
                              currentUserId: currentUserId,
                              onTap: () => context.push('/chat/${conv.id}'),
                            );
                          },
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (e, _) => AppErrorWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(conversationsProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveUsersHorizontal(List<ConversationModel> conversations) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Lấy tối đa 8 liên hệ độc nhất từ danh sách
    final uniqueUsers = <String, dynamic>{};
    for (var c in conversations) {
      if (c.otherUser != null) {
        uniqueUsers[c.otherUser!.id] = c;
      }
    }

    if (uniqueUsers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'HOẠT ĐỘNG GẦN ĐÂY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70),
              letterSpacing: 0.4,
            ),
          ),
        ),
        SizedBox(
          height: 94,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: uniqueUsers.length,
            itemBuilder: (context, index) {
              final conv = uniqueUsers.values.elementAt(index) as ConversationModel;
              final user = conv.otherUser!;

              // Chỉ lấy từ đầu tiên của tên để hiển thị gọn gàng
              final firstName = user.displayName.split(' ').first;

              return CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: () => context.push('/chat/${conv.id}'),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        AppAvatar(
                          imageUrl: user.avatarUrl,
                          name: user.displayName,
                          radius: 26,
                        ),
                        Positioned(
                          right: 1,
                          bottom: 1,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: const Color(0xFF34C759), // iOS green status
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.scaffoldBackgroundColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 60,
                      child: Text(
                        firstName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          child: Divider(
            height: 0.5,
            thickness: 0.5,
            color: theme.dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ],
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

    final hasUnread = conv.lastMessageSenderId != currentUserId && conv.lastMessage != null; // Mock unread indicator
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
              // ── Unread Indicator (iOS Blue Dot) ───────────────────
              if (hasUnread)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF007AFF), // iOS System Blue
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(width: 0),

              // ── Avatar ────────────────────────────────────────────
              Stack(
                children: [
                  AppAvatar(
                    imageUrl: conv.otherUser?.avatarUrl,
                    name: conv.otherUser?.displayName,
                    radius: 28,
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // ── Text Content ──────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      conv.otherUser?.displayName ?? 'Người dùng',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
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
                        fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // ── Time & Chevron ────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    conv.lastMessageAt?.chatTimestamp ?? '',
                    style: TextStyle(
                      color: hasUnread ? const Color(0xFF007AFF) : hintColor,
                      fontSize: 12,
                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
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
