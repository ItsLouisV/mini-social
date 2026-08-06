import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../../../profile/domain/profile_model.dart';
import '../../providers/chat_provider.dart';

class ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String conversationId;
  final String chatTitle;
  final String? avatarUrl;
  final bool isGroup;
  final int memberCount;
  final ProfileModel? otherUser;
  final bool hasWallpaper;
  final VoidCallback? onSearchTap;
  final VoidCallback? onVideoCallTap;
  final VoidCallback? onVoiceCallTap;
  final VoidCallback? onSettingsTap;

  const ChatAppBar({
    super.key,
    required this.conversationId,
    required this.chatTitle,
    this.avatarUrl,
    this.isGroup = false,
    this.memberCount = 0,
    this.otherUser,
    this.hasWallpaper = false,
    this.onSearchTap,
    this.onVideoCallTap,
    this.onVoiceCallTap,
    this.onSettingsTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final themeState = ref.watch(chatThemeColorProvider);
    final themeName = themeState[conversationId] ?? 'blue';
    final chatThemeColor = getChatThemePrimaryColor(themeName);

    Widget buildHeaderButton({
      required Widget icon,
      required VoidCallback onPressed,
      required String tooltip,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onPressed,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: chatThemeColor.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: chatThemeColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(child: icon),
            ),
          ),
        ),
      );
    }

    return AppBar(
      titleSpacing: 0,
      elevation: hasWallpaper ? 0 : 0.5,
      backgroundColor: hasWallpaper
          ? theme.scaffoldBackgroundColor.withValues(alpha: 0.7)
          : (isDark ? theme.colorScheme.surface : Colors.white),
      leading: IconButton(
        icon: Icon(
          CupertinoIcons.back,
          color: isDark ? Colors.white : Colors.black87,
        ),
        onPressed: () => context.pop(),
      ),
      title: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (isGroup) {
                  context.push('/chat/$conversationId/settings');
                } else if (otherUser != null) {
                  context.push('/profile/${otherUser!.id}');
                }
              },
              child: Row(
                children: [
                  AppAvatar(
                    imageUrl: avatarUrl,
                    name: chatTitle,
                    radius: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chatTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isGroup)
                          Text(
                            '$memberCount thành viên',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else if (otherUser != null)
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Hoạt động',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (onSearchTap != null)
          buildHeaderButton(
            icon: const Icon(CupertinoIcons.search,
                color: Colors.white, size: 18),
            onPressed: onSearchTap!,
            tooltip: 'Tìm kiếm',
          ),
        buildHeaderButton(
          icon: const Icon(CupertinoIcons.videocam_circle,
              color: Colors.white, size: 22),
          onPressed: onVideoCallTap ??
              () {
                if (otherUser?.id == null) return;
                context.push('/call/outgoing', extra: {
                  'conversationId': conversationId,
                  'calleeId': otherUser!.id,
                  'calleeName': chatTitle,
                  'avatarUrl': avatarUrl,
                  'isVideo': true,
                });
              },
          tooltip: 'Gọi video',
        ),
        buildHeaderButton(
          icon: const Icon(CupertinoIcons.phone,
              color: Colors.white, size: 18),
          onPressed: onVoiceCallTap ??
              () {
                if (otherUser?.id == null) return;
                context.push('/call/outgoing', extra: {
                  'conversationId': conversationId,
                  'calleeId': otherUser!.id,
                  'calleeName': chatTitle,
                  'avatarUrl': avatarUrl,
                  'isVideo': false,
                });
              },
          tooltip: 'Gọi thoại',
        ),
        buildHeaderButton(
          icon: const Icon(CupertinoIcons.ellipsis,
              color: Colors.white, size: 18),
          onPressed: onSettingsTap ??
              () => context.push('/chat/$conversationId/settings'),
          tooltip: 'Thiết lập',
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Divider(
          height: 0.5,
          thickness: 0.5,
          color: hasWallpaper
              ? Colors.transparent
              : theme.dividerColor.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}
