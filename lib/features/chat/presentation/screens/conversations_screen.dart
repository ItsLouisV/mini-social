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
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../domain/conversation_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/hidden_chat_provider.dart';
import '../widgets/create_group_modal.dart';
import '../widgets/new_message_modal.dart';
import '../widgets/passcode_dialog.dart';
import '../widgets/slidable_circular_action_button.dart';
import '../../../../core/services/connectivity_service.dart';

import '../../../../shared/widgets/skeletons/tile_skeleton_loading.dart';

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

    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: Text(
          AppTranslations.tr(ref, 'messages'),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            fontSize: 24,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: FaIcon(
              FontAwesomeIcons.squarePlus,
              size: 22,
              color: theme.iconTheme.color,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            offset: const Offset(0, 42),
            onSelected: (value) async {
              switch (value) {
                case 'create_group':
                  final groupConvId = await CreateGroupModal.show(context);
                  if (groupConvId != null && context.mounted) {
                    context.push('/chat/$groupConvId');
                  }
                  break;
                case 'new_chat':
                  final result = await NewMessageModal.show(context);
                  if (result != null && context.mounted) {
                    await context.push('/chat/$result');
                  }
                  break;
                case 'add_friend':
                  context.push('/my-qr');
                  break;
                case 'hidden_chats':
                  final convs =
                      ref.read(conversationsProvider).valueOrNull ?? [];
                  final currentUserId = ref.read(currentUserIdProvider);
                  final hiddenCount = currentUserId == null
                      ? 0
                      : convs.where((c) => c.isHidden(currentUserId)).length;

                  if (hiddenCount == 0) {
                    await ref
                        .read(hiddenChatProvider.notifier)
                        .removePasscode();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Chưa có cuộc trò chuyện nào bị ẩn')),
                      );
                    }
                  } else {
                    final success = await PasscodeDialog.show(context,
                        mode: PasscodeMode.verify);
                    if (success == true && context.mounted) {
                      context.push('/chat/hidden');
                    }
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'create_group',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5856D6).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.person_3_fill,
                          color: Color(0xFF5856D6), size: 16),
                    ),
                    const SizedBox(width: 12),
                    const Text('Tạo nhóm mới',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'new_chat',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.chat_bubble_fill,
                          color: Color(0xFF34C759), size: 16),
                    ),
                    const SizedBox(width: 12),
                    const Text('Tin nhắn mới',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'add_friend',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9F0A).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.person_badge_plus,
                          color: Color(0xFFFF9F0A), size: 16),
                    ),
                    const SizedBox(width: 12),
                    const Text('Thêm bạn mới',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'hidden_chats',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.eye_slash_fill,
                          color: Colors.grey, size: 16),
                    ),
                    const SizedBox(width: 12),
                    const Text('Cuộc trò chuyện ẩn',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              ),
            ],
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
            final isHidden = currentUserId != null && c.isHidden(currentUserId);
            if (isHidden && _searchQuery.isEmpty) return false;
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
              if (!isOnline)
                Container(
                  width: double.infinity,
                  color: Colors.amber.withValues(alpha: 0.15),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.wifi_slash,
                          color: Colors.amber, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Đang ngoại tuyến.',
                        style: TextStyle(
                          color: theme.brightness == Brightness.dark
                              ? Colors.amber[200]
                              : Colors.amber[800],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: AppTranslations.tr(ref, 'search'),
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  placeholderStyle: TextStyle(color: theme.hintColor),
                  backgroundColor: theme.brightness == Brightness.dark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFF767680).withValues(alpha: 0.12),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
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
                    : IOSSlidableAutoCloseBehavior(
                        child: ListView.separated(
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
                            final isHidden = currentUserId != null &&
                                conv.isHidden(currentUserId);
                            return _ConversationTile(
                              conv: conv,
                              currentUserId: currentUserId,
                              isSearching: _searchQuery.isNotEmpty,
                              onTap: () async {
                                if (isHidden) {
                                  final success = await PasscodeDialog.show(
                                      context,
                                      mode: PasscodeMode.verify);
                                  if (success == true && context.mounted) {
                                    context.push('/chat/${conv.id}');
                                  }
                                } else {
                                  context.push('/chat/${conv.id}');
                                }
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () =>
            const TileSkeletonLoading(hasSearchBar: true, itemCount: 8),
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
  final bool isSearching;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conv,
    required this.currentUserId,
    this.isSearching = false,
    required this.onTap,
  });

  double _actionExtentRatio(
    BuildContext context,
    int actionCount,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Không chỉ circle 42px.
    // Cần cả khoảng trống xung quanh action để swipe nhìn thoáng.
    const actionSlotWidth = 72.0;

    final requiredWidth = actionSlotWidth * actionCount;

    return (requiredWidth / screenWidth).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasUnread =
        (currentUserId != null) && (conv.getUnreadCount(currentUserId!) > 0);
    final isHidden = (currentUserId != null) && conv.isHidden(currentUserId!);
    final titleColor = theme.textTheme.titleMedium?.color;
    final hintColor = theme.hintColor;

    final lastSenderProfile = (conv.isGroup &&
            conv.lastMessageSenderId != null &&
            conv.lastMessageSenderId != currentUserId)
        ? ref.watch(profileProvider(conv.lastMessageSenderId!)).valueOrNull
        : null;
    final lastSenderName =
        lastSenderProfile?.displayName ?? lastSenderProfile?.fullName;

    String displayLastMessage;
    if (conv.lastMessage != null) {
      if (conv.lastMessageSenderId == currentUserId) {
        displayLastMessage = 'Bạn: ${conv.lastMessage}';
      } else if (conv.isGroup && lastSenderName != null) {
        displayLastMessage = '$lastSenderName: ${conv.lastMessage}';
      } else {
        displayLastMessage = conv.lastMessage!;
      }
    } else {
      displayLastMessage = 'Bắt đầu cuộc trò chuyện';
    }

    return IOSRubberbandSlidableTile(
      startActions: [
        SlidableActionItem(
          icon: conv.isPinned(currentUserId ?? '')
              ? CupertinoIcons.pin_slash_fill
              : CupertinoIcons.pin_fill,
          label: conv.isPinned(currentUserId ?? '')
              ? AppTranslations.tr(ref, 'unpin')
              : AppTranslations.tr(ref, 'pin'),
          color: const Color(0xFFFF9500),
          onTap: () async {
            await ref.read(chatRepositoryProvider).togglePin(conv);
            ref.invalidate(conversationsProvider);
          },
        ),
      ],
      endActions: [
        SlidableActionItem(
          icon: CupertinoIcons.eye_slash_fill,
          label: AppTranslations.tr(ref, 'hide_conversation'),
          color: const Color(0xFF5856D6),
          onTap: () async {
            final convs = ref.read(conversationsProvider).valueOrNull ?? [];
            final hiddenCount = currentUserId == null
                ? 0
                : convs.where((c) => c.isHidden(currentUserId!)).length;

            if (hiddenCount == 0) {
              await ref.read(hiddenChatProvider.notifier).removePasscode();
              if (!context.mounted) return;

              final success = await PasscodeDialog.show(
                context,
                mode: PasscodeMode.setup,
              );

              if (success == true) {
                await ref.read(chatRepositoryProvider).toggleHide(conv);
                ref.invalidate(conversationsProvider);
              }
            } else {
              await ref.read(chatRepositoryProvider).toggleHide(conv);
              ref.invalidate(conversationsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã ẩn cuộc trò chuyện')),
                );
              }
            }
          },
        ),
        SlidableActionItem(
          icon: CupertinoIcons.trash_fill,
          label: AppTranslations.tr(ref, 'delete_chat'),
          color: const Color(0xFFFF3B30),
          onTap: () {
            showCupertinoDialog(
              context: context,
              builder: (ctx) => CupertinoAlertDialog(
                title: Text(AppTranslations.tr(ref, 'delete_chat')),
                content: const Text(
                  'Thao tác này sẽ xoá toàn bộ tin nhắn ở cả 2 phía. Bạn có chắc chắn không?',
                ),
                actions: [
                  CupertinoDialogAction(
                    child: Text(AppTranslations.tr(ref, 'cancel')),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(ctx);
                      ref
                          .read(chatRepositoryProvider)
                          .deleteConversation(conv.id);
                    },
                    child: Text(AppTranslations.tr(ref, 'delete_chat')),
                  ),
                ],
              ),
            );
          },
        ),
      ],

      // ==========================================================
      // MAIN CONTENT
      // ==========================================================
      child: Material(
        color: conv.isPinned(currentUserId ?? '')
            ? (isDark
                ? Colors.white.withValues(alpha: 0.03)
                : theme.scaffoldBackgroundColor)
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
                  imageUrl: conv.isGroup
                      ? conv.groupAvatarUrl
                      : conv.otherUser?.avatarUrl,
                  name: conv.isGroup
                      ? (conv.groupName ?? 'Group')
                      : conv.otherUser?.displayName,
                  radius: 25,
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
                              conv.isGroup
                                  ? (conv.groupName ?? 'Nhóm trò chuyện')
                                  : (conv.otherUser?.displayName ??
                                      'Người dùng'),
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
                          if (isHidden)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                CupertinoIcons.eye_slash_fill,
                                size: 12,
                                color: hintColor,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Khi đang tìm kiếm: CHỈ hiển thị username/thành viên, ẨN HOÀN TOÀN lastMessage
                      if (isSearching)
                        Text(
                          conv.isGroup
                              ? '${conv.members?.length ?? 0} thành viên'
                              : (conv.otherUser?.username != null
                                  ? '@${conv.otherUser!.username}'
                                  : ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hintColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        )
                      else
                        Text(
                          displayLastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasUnread
                                ? (isDark ? Colors.white : Colors.black)
                                : hintColor,
                            fontWeight:
                                hasUnread ? FontWeight.w500 : FontWeight.w400,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Time & chevron (Khi tìm kiếm: CHỈ hiển thị chevron, ẩn timestamp)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isSearching) ...[
                      Text(
                        conv.lastMessageAt?.chatTimestamp ?? '',
                        style: TextStyle(
                          color:
                              hasUnread ? const Color(0xFF007AFF) : hintColor,
                          fontSize: 12,
                          fontWeight:
                              hasUnread ? FontWeight.w500 : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
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
