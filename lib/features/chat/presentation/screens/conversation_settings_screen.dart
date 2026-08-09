import 'dart:io' as io;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/full_screen_image_viewer.dart';

import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/services/toast_service.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/domain/profile_model.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../../social/providers/follow_list_provider.dart';
import '../../domain/conversation_member_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/hidden_chat_provider.dart';
import '../../domain/group_permissions.dart';
import '../widgets/message_context_menu_route.dart';
import '../widgets/passcode_dialog.dart';

class ConversationSettingsScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ConversationSettingsScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ConversationSettingsScreen> createState() => _ConversationSettingsScreenState();
}

class _ConversationSettingsScreenState extends ConsumerState<ConversationSettingsScreen> {
  // Centralized themes configuration imported from chat_provider.dart

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final convAsync = ref.watch(conversationsProvider);
    final currentUserId = ref.watch(currentUserIdProvider) ?? '';
    final wallpaperState = ref.watch(chatWallpaperProvider);
    final muteState = ref.watch(chatMuteProvider);
    final themeState = ref.watch(chatThemeColorProvider);
    final activeThemeId = themeState[widget.conversationId] ?? 'blue';
    final activeThemeItem = kChatThemes.firstWhere((t) => t.id == activeThemeId, orElse: () => kChatThemes.first);


    // Fetch shared media images from the conversation history
    final messagesAsync = ref.watch(realtimeMessagesProvider(widget.conversationId));
    final mediaMessages = messagesAsync.valueOrNull?.messages
            .where((m) => m.isImage)
            .toList() ??
        [];

    // Background color styling for high-end look
    final bgColor = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF6F8FA);
    final cardBgColor = isDark ? const Color(0xFF1E1E2F) : Colors.white;
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          AppTranslations.tr(ref, 'conversation_info'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.2),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(CupertinoIcons.left_chevron, color: theme.colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: convAsync.when(
        data: (convList) {
          final conv = convList.firstWhere(
            (c) => c.id == widget.conversationId,
            orElse: () => throw Exception('Conversation not found'),
          );

          final isGroup = conv.isGroup == true;
          final otherUser = conv.otherUser;
          final otherUserName = otherUser?.displayName ?? 'Người dùng';
          final chatTitle = isGroup ? (conv.groupName ?? 'Nhóm trò chuyện') : otherUserName;
          final otherUserUsername = otherUser?.username ?? '';
          final avatarUrl = isGroup ? conv.groupAvatarUrl : otherUser?.avatarUrl;

          final membersAsync = ref.watch(groupMembersProvider(widget.conversationId));
          final memberCount = membersAsync.valueOrNull?.length ?? (conv.members?.length ?? 0);
          // ── Correct admin check: use role from member model, not createdBy ──
          final myMember = ref.watch(groupMemberMeProvider(widget.conversationId));
          final isOwner = myMember?.isOwner ?? (conv.groupAdminId == currentUserId);
          final isGroupAdmin = myMember?.isAdmin ?? isOwner;
          final perms = ref.watch(groupPermissionsProvider(widget.conversationId));

          final isPinned = conv.isPinned(currentUserId);
          final isMuted = muteState[widget.conversationId] ?? false;
          final isHidden = conv.isHidden(currentUserId);
          final wallpaperPath = wallpaperState[widget.conversationId] ?? '';

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // ── Top profile header card ──────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: isGroup ? () => _pickAndChangeGroupAvatar(context, ref, conv) : null,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: activeThemeItem.color.withValues(alpha: 0.4),
                                width: 3,
                              ),
                            ),
                            child: AppAvatar(
                              imageUrl: avatarUrl,
                              name: chatTitle,
                              radius: 48,
                            ),
                          ),
                        ),
                        if (isGroup)
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => _pickAndChangeGroupAvatar(context, ref, conv),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: bgColor, width: 2),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: const Icon(CupertinoIcons.camera_fill, color: Colors.white, size: 14),
                              ),
                            ),
                          )
                        else
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFF34C759),
                                shape: BoxShape.circle,
                                border: Border.all(color: bgColor, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          chatTitle,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (isGroup) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _showRenameGroupDialog(context, ref, conv),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(CupertinoIcons.pencil, size: 14, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isGroup
                          ? 'Nhóm trò chuyện • $memberCount thành viên'
                          : (otherUserUsername.isNotEmpty ? '@$otherUserUsername' : 'Đang hoạt động'),
                      style: TextStyle(
                        fontSize: 13,
                        color: isGroup ? theme.hintColor : const Color(0xFF34C759),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Quick horizontal action buttons ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickAction(
                    icon: isMuted ? CupertinoIcons.bell_slash_fill : CupertinoIcons.bell_fill,
                    label: isMuted ? 'Bật tiếng' : 'Tắt tiếng',
                    color: Colors.purple,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(chatMuteProvider.notifier).toggleMute(widget.conversationId);
                    },
                  ),
                  _buildQuickAction(
                    icon: CupertinoIcons.person_crop_circle_fill,
                    label: 'Hồ sơ',
                    color: Colors.teal,
                    onTap: () {
                      if (otherUser != null) {
                        context.push('/profile/${otherUser.id}');
                      }
                    },
                  ),
                  _buildQuickAction(
                    icon: CupertinoIcons.phone_fill,
                    label: 'Gọi điện',
                    color: Colors.blue,
                    onTap: () {
                      if (otherUser?.id == null) return;
                      context.push('/call/outgoing', extra: {
                        'conversationId': widget.conversationId,
                        'calleeId': otherUser!.id,
                        'calleeName': otherUserName,
                        'avatarUrl': otherUser.avatarUrl,
                        'isVideo': false,
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // ── Group 1: Shared Media Section ────────────────────────────────────
              _buildSectionHeader('PHƯƠNG TIỆN & TỆP CHIA SẺ'),
              _buildCardContainer(
                cardBgColor,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => context.push('/chat/${widget.conversationId}/media'),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Ảnh & Video (${mediaMessages.length})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const Icon(CupertinoIcons.right_chevron, size: 14, color: Colors.grey),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (mediaMessages.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Icon(CupertinoIcons.photo_on_rectangle, size: 36, color: theme.hintColor.withValues(alpha: 0.4)),
                                const SizedBox(height: 6),
                                Text(
                                  'Chưa có hình ảnh nào được chia sẻ',
                                  style: TextStyle(color: theme.hintColor, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        else
                          SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: mediaMessages.length,
                              itemBuilder: (context, idx) {
                                final msg = mediaMessages[idx];
                                return GestureDetector(
                                  onTap: () => _openSharedImage(context, msg.firstMediaUrl!),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: dividerColor),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(9),
                                      child: Hero(
                                        tag: msg.firstMediaUrl!,
                                        child: CachedNetworkImage(
                                          imageUrl: msg.firstMediaUrl!,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => const Center(child: CupertinoActivityIndicator(radius: 8)),
                                          errorWidget: (_, __, ___) => const Icon(CupertinoIcons.photo),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isGroup) ...[
                const SizedBox(height: 24),
                _buildGroupMembersSection(context, ref, conv, currentUserId, cardBgColor, dividerColor, isGroupAdmin, isOwner, perms),
                const SizedBox(height: 24),
              ],

              // ── Group 2: Personalizations ────────────────────────────────────────
              _buildSectionHeader('TÙY CHỈNH CHAT'),
              _buildCardContainer(
                cardBgColor,
                children: [
                  _buildListTile(
                    context: context,
                    icon: CupertinoIcons.photo,
                    gradientColors: [Colors.blue, Colors.indigo],
                    title: 'Hình nền trò chuyện',
                    subtitle: wallpaperPath.isNotEmpty ? 'Đã kích hoạt ảnh nền tùy chọn' : 'Mặc định',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (wallpaperPath.isNotEmpty)
                          Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: _buildWallpaperPreview(wallpaperPath),
                            ),
                          ),
                        const Icon(CupertinoIcons.right_chevron, size: 16, color: Colors.grey),
                      ],
                    ),
                    onTap: () => context.push('/chat/${widget.conversationId}/wallpaper-history'),
                  ),
                  Divider(height: 0.5, thickness: 0.5, color: dividerColor, indent: 56),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Chủ đề cuộc trò chuyện',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              activeThemeItem.name,
                              style: TextStyle(fontSize: 13, color: activeThemeItem.color, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 36,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: kChatThemes.length,
                            itemBuilder: (context, idx) {
                              final item = kChatThemes[idx];
                              final isSelected = activeThemeId == item.id;
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  ref.read(chatThemeColorProvider.notifier).setTheme(widget.conversationId, item.id);
                                  ScaffoldMessenger.of(context).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Đã cập nhật chủ đề chat sang ${item.name}'),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: item.color,
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(color: isDark ? Colors.white : Colors.black87, width: 3)
                                        : null,
                                    boxShadow: [
                                      BoxShadow(
                                        color: item.color.withValues(alpha: 0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: isSelected
                                      ? const Icon(CupertinoIcons.checkmark, size: 14, color: Colors.white)
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Group 3: Privacy & Security ──────────────────────────────────────
              _buildSectionHeader('BẢO MẬT & QUYỀN RIÊNG TƯ'),
              _buildCardContainer(
                cardBgColor,
                children: [
                  _buildSwitchTile(
                    icon: isHidden ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill,
                    gradientColors: const [Colors.blueGrey, Colors.grey],
                    title: 'Ẩn cuộc trò chuyện',
                    value: isHidden,
                    onChanged: (val) {
                      _handleToggleHide(context, ref, conv, currentUserId);
                    },
                  ),

                ],
              ),
              const SizedBox(height: 24),

              // ── Group 4: Conversation Settings ───────────────────────────────────
              _buildSectionHeader('CÀI ĐẶT CHUNG'),
              _buildCardContainer(
                cardBgColor,
                children: [
                  _buildSwitchTile(
                    icon: CupertinoIcons.pin_fill,
                    gradientColors: [Colors.amber, Colors.orange],
                    title: 'Ghim cuộc trò chuyện',
                    value: isPinned,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      ref.read(chatRepositoryProvider).togglePin(conv);
                    },
                  ),
                  Divider(height: 0.5, thickness: 0.5, color: dividerColor, indent: 56),
                  _buildSwitchTile(
                    icon: isMuted ? CupertinoIcons.bell_slash_fill : CupertinoIcons.bell_fill,
                    gradientColors: [Colors.purple, Colors.deepPurple],
                    title: 'Tắt thông báo',
                    value: isMuted,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      ref.read(chatMuteProvider.notifier).toggleMute(widget.conversationId);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Group 5: Danger Zone ─────────────────────────────────────────────
              _buildSectionHeader('HÀNH ĐỘNG'),
              Builder(builder: (context) {
                if (isGroup) {
                  return _buildCardContainer(
                    cardBgColor,
                    children: [
                      if (isGroupAdmin)
                        _buildListTile(
                          context: context,
                          icon: CupertinoIcons.settings_solid,
                          gradientColors: [Colors.indigo, Colors.purple],
                          title: 'Quản lý nhóm',
                          subtitle: 'Quyền, mute, cấm thành viên...',
                          trailing: const Icon(CupertinoIcons.right_chevron, size: 16, color: Colors.grey),
                          onTap: () => context.pushNamed('group-management', pathParameters: {'conversationId': widget.conversationId}),
                        ),
                      if (isGroupAdmin)
                        Divider(height: 0.5, thickness: 0.5, color: dividerColor, indent: 56),
                      if (isOwner)
                        _buildListTile(
                          context: context,
                          icon: CupertinoIcons.trash,
                          gradientColors: [Colors.red, Colors.deepOrange],
                          title: 'Giải tán nhóm trò chuyện',
                          titleColor: Colors.red,
                          trailing: const SizedBox.shrink(),
                          onTap: () => _confirmDissolveGroup(context, ref, conv),
                        )
                      else
                        _buildListTile(
                          context: context,
                          icon: CupertinoIcons.arrow_right_square,
                          gradientColors: [Colors.orange, Colors.redAccent],
                          title: 'Rời khỏi nhóm',
                          titleColor: Colors.redAccent,
                          trailing: const SizedBox.shrink(),
                          onTap: () => _confirmLeaveGroup(context, ref, conv, isOwner, membersAsync.valueOrNull ?? []),
                        ),
                    ],
                  );
                }

                final isChatBlocked = ref.watch(isChatBlockedProvider(otherUser?.id ?? ''));
                return _buildCardContainer(
                  cardBgColor,
                  children: [
                    _buildListTile(
                      context: context,
                      icon: isChatBlocked ? CupertinoIcons.checkmark_shield_fill : CupertinoIcons.slash_circle,
                      gradientColors: isChatBlocked ? [Colors.grey, Colors.blueGrey] : [Colors.redAccent, Colors.red],
                      title: isChatBlocked ? 'Đã chặn tin nhắn từ người này' : 'Chặn tin nhắn từ người này',
                      titleColor: isChatBlocked ? Colors.grey : Colors.red,
                      trailing: const SizedBox.shrink(),
                      onTap: () => _confirmChatBlockUser(context, ref, otherUser?.id ?? '', otherUserName, isChatBlocked),
                    ),
                    Divider(height: 0.5, thickness: 0.5, color: dividerColor, indent: 56),
                    _buildListTile(
                      context: context,
                      icon: CupertinoIcons.trash,
                      gradientColors: [Colors.red, Colors.deepOrange],
                      title: 'Xóa lịch sử trò chuyện',
                      titleColor: Colors.red,
                      trailing: const SizedBox.shrink(),
                      onTap: () => _confirmDeleteConversation(context, ref, conv),
                    ),
                  ],
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (err, _) => Scaffold(body: Center(child: Text('Lỗi: $err'))),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCardContainer(Color cardBgColor, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? color.withValues(alpha: 0.18) : color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required BuildContext context,
    required IconData icon,
    required List<Color> gradientColors,
    required String title,
    String? subtitle,
    Color? titleColor,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: titleColor ?? theme.textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: theme.hintColor),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required List<Color> gradientColors,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: CupertinoSwitch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  // System wallpaper gradient colours (mirrors wallpaper_history_screen.dart)
  static const _kSysGradients = <String, List<Color>>{
    'sys:aurora':   [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
    'sys:sunset':   [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
    'sys:ocean':    [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
    'sys:lavender': [Color(0xFF667EEA), Color(0xFF764BA2)],
    'sys:mint':     [Color(0xFF11998E), Color(0xFF38EF7D)],
    'sys:rose':     [Color(0xFFFC5C7D), Color(0xFF6A3093)],
    'sys:peach':    [Color(0xFFFFB347), Color(0xFFFF6B35)],
    'sys:midnight': [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
    'sys:sakura':   [Color(0xFFFFE0EC), Color(0xFFFFC5D9), Color(0xFFFFABC8)],
    'sys:forest':   [Color(0xFF1B4332), Color(0xFF2D6A4F), Color(0xFF52B788)],
    'sys:galaxy':   [Color(0xFF200122), Color(0xFF6F0000)],
    'sys:sky':      [Color(0xFF56CCF2), Color(0xFF2F80ED)],
  };

  Widget _buildWallpaperPreview(String path) {
    // System gradient wallpaper
    if (path.startsWith('sys:')) {
      final colors = _kSysGradients[path];
      if (colors != null) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    if (path.startsWith('blob:')) {
      return const Icon(CupertinoIcons.photo, size: 16);
    } else if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.photo, size: 16),
      );
    } else if (kIsWeb) {
      return const Icon(CupertinoIcons.photo, size: 16);
    } else {
      return Image.file(
        io.File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.photo, size: 16),
      );
    }
  }

  void _openSharedImage(BuildContext context, String imageUrl) {
    FullScreenImageViewer.open(context, imageUrl);
  }





  Future<void> _handleToggleHide(BuildContext context, WidgetRef ref, dynamic conv, String currentUserId) async {
    final isHidden = conv.isHidden(currentUserId);
    if (isHidden) {
      final success = await PasscodeDialog.show(context, mode: PasscodeMode.verify);
      if (success == true) {
        ref.read(chatRepositoryProvider).toggleHide(conv);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã hiển thị lại cuộc trò chuyện')),
          );
        }
      }
    } else {
      final convs = ref.read(conversationsProvider).valueOrNull ?? [];
      final hiddenCount = convs.where((c) => c.isHidden(currentUserId)).length;

      if (hiddenCount == 0) {
        await ref.read(hiddenChatProvider.notifier).removePasscode();
        if (!context.mounted) return;
        final success = await PasscodeDialog.show(context, mode: PasscodeMode.setup);
        if (success == true) {
          ref.read(chatRepositoryProvider).toggleHide(conv);
          if (context.mounted) {
            context.go('/chat');
          }
        }
      } else {
        ref.read(chatRepositoryProvider).toggleHide(conv);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã ẩn cuộc trò chuyện')),
          );
          context.go('/chat');
        }
      }
    }
  }

  void _confirmChatBlockUser(BuildContext context, WidgetRef ref, String targetUserId, String userName, bool isChatBlocked) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(isChatBlocked ? 'Bỏ chặn tin nhắn từ $userName?' : 'Chặn tin nhắn từ $userName?'),
        content: Text(
          isChatBlocked
              ? 'Người dùng này sẽ có thể nhắn tin cho bạn trở lại.'
              : 'Người dùng này sẽ không thể nhắn tin cho bạn nữa.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Huỷ'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: !isChatBlocked,
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                if (isChatBlocked) {
                  await ref.read(profileRepositoryProvider).chatUnblockUser(targetUserId);
                } else {
                  await ref.read(profileRepositoryProvider).chatBlockUser(targetUserId);
                }
                ref.invalidate(chatBlockedUserIdsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isChatBlocked
                          ? 'Đã bỏ chặn tin nhắn từ $userName'
                          : 'Đã chặn tin nhắn từ $userName'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(isChatBlocked ? 'Bỏ chặn' : 'Chặn tin nhắn'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteConversation(BuildContext context, WidgetRef ref, dynamic conv) {
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
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx);
              context.go('/chat');
              await ref.read(chatRepositoryProvider).deleteConversation(conv.id);
            },
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }

  void _showRenameGroupDialog(BuildContext context, WidgetRef ref, dynamic conv) {
    final controller = TextEditingController(text: conv.groupName ?? '');
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Đổi tên nhóm'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Nhập tên nhóm mới...',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Hủy'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(ctx);
                await ref.read(chatRepositoryProvider).updateGroupName(conv.id, newName);
                ref.invalidate(conversationsProvider);
                if (context.mounted) {
                  ToastService.showSuccess(context, 'Đã cập nhật tên nhóm mới');
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndChangeGroupAvatar(BuildContext context, WidgetRef ref, dynamic conv) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    ToastService.showInfo(context, 'Đang tải ảnh nhóm mới...');
    try {
      await ref.read(chatRepositoryProvider).updateGroupAvatar(conv.id, picked);
      ref.invalidate(conversationsProvider);
      if (context.mounted) {
        ToastService.showSuccess(context, 'Đã đổi ảnh nhóm mới thành công!');
      }
    } catch (e) {
      if (context.mounted) {
        ToastService.showError(context, 'Lỗi đổi ảnh nhóm: $e');
      }
    }
  }

  Widget _buildGroupMembersSection(
    BuildContext context,
    WidgetRef ref,
    dynamic conv,
    String currentUserId,
    Color cardBgColor,
    Color dividerColor,
    bool isGroupAdmin,
    bool isOwner,
    GroupPermissions? perms,
  ) {
    final membersAsync = ref.watch(groupMembersProvider(conv.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('DANH SÁCH THÀNH VIÊN'),
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: GestureDetector(
                onTap: () => _showAddMemberModal(context, ref, conv),
                child: const Row(
                  children: [
                    Icon(CupertinoIcons.person_badge_plus, size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Thêm thành viên',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        _buildCardContainer(
          cardBgColor,
          children: [
            membersAsync.when(
              data: (members) {
                if (members.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Chưa có danh sách thành viên'),
                  );
                }
                return Column(
                  children: members.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final m = entry.value;
                    final isMe = m.userId == currentUserId;
                    final itemKey = GlobalKey();

                    return Column(
                      children: [
                        ListTile(
                          key: itemKey,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: AppAvatar(
                            imageUrl: m.profile?.avatarUrl,
                            name: m.profile?.displayName ?? 'Thành viên',
                            radius: 20,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  isMe ? '${m.profile?.displayName ?? "Tôi"} (Tôi)' : (m.profile?.displayName ?? 'Thành viên'),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (m.isOwner)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('👑 ', style: TextStyle(fontSize: 10)),
                                      Text('Trưởng nhóm', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
                                    ],
                                  ),
                                )
                              else if (m.isCoAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('⭐ ', style: TextStyle(fontSize: 10)),
                                      Text('Phó nhóm', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            m.profile?.username != null && m.profile!.username.isNotEmpty ? '@${m.profile!.username}' : 'Thành viên nhóm',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: const Icon(CupertinoIcons.ellipsis, size: 18, color: Colors.grey),
                          onTap: () => _showMemberContextMenu(context, ref, conv, m, itemKey, isGroupAdmin, isOwner, isMe, currentUserId, cardBgColor),
                        ),
                        if (idx < members.length - 1)
                          Divider(height: 0.5, thickness: 0.5, color: dividerColor, indent: 56),
                      ],
                    );
                  }).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: CupertinoActivityIndicator(),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Lỗi tải thành viên: $err'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showMemberContextMenu(
    BuildContext context,
    WidgetRef ref,
    dynamic conv,
    ConversationMemberModel member,
    GlobalKey itemKey,
    bool isGroupAdmin,
    bool isOwner,
    bool isMe,
    String currentUserId,
    Color cardBgColor,
  ) {
    HapticFeedback.mediumImpact();
    final renderBox = itemKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    final overlayMemberWidget = Container(
      width: size.width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          AppAvatar(
            imageUrl: member.profile?.avatarUrl,
            name: member.profile?.displayName ?? 'Thành viên',
            radius: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isMe ? '${member.profile?.displayName ?? "Tôi"} (Tôi)' : (member.profile?.displayName ?? 'Thành viên'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (member.isOwner)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('👑 Trưởng nhóm', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
                      )
                    else if (member.isCoAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('⭐ Phó nhóm', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
                      ),
                  ],
                ),
                if (member.profile?.username != null && member.profile!.username.isNotEmpty)
                  Text(
                    '@${member.profile!.username}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    Navigator.push(
      context,
      MessageContextMenuRoute(
        messagePosition: position,
        messageSize: size,
        messageWidget: overlayMemberWidget,
        isMine: false,
        estimatedMenuHeight: 110.0,
        menuContentWidget: MemberPopupMenuContent(
          member: member,
          isCoAdmin: member.isCoAdmin,
          isGroupAdmin: isGroupAdmin,
          isOwner: isOwner,
          isMe: isMe,
          onToggleCoAdmin: () async {
            Navigator.pop(context);
            // Only owner can promote/demote (phó nhóm only set by owner)
            if (!isOwner) return;
            final newRole = member.isCoAdmin ? 'member' : 'admin';
            await ref.read(chatRepositoryProvider).updateMemberRole(conv.id, member.userId, newRole);
            ref.invalidate(groupMembersProvider(conv.id));
            ref.invalidate(conversationsProvider);
            if (context.mounted) {
              ToastService.showSuccess(
                context,
                member.isCoAdmin ? 'Đã gỡ quyền Phó nhóm' : 'Đã thăng cấp làm Phó nhóm',
              );
            }
          },
          onMuteMember: isGroupAdmin && !isMe && !member.isOwner
              ? () => _showMuteDurationPicker(context, ref, conv.id, member)
              : null,
          onBanMember: isOwner && !isMe && !member.isOwner
              ? () async {
                  Navigator.pop(context);
                  await _confirmBanMember(context, ref, conv.id, member);
                }
              : null,
          onTransferOwnership: isOwner && !isMe && !member.isOwner
              ? () async {
                  Navigator.pop(context);
                  await _confirmTransferOwnership(context, ref, conv.id, member);
                }
              : null,
          onRemoveMember: () async {
            Navigator.pop(context);
            await ref.read(chatRepositoryProvider).removeGroupMember(conv.id, member.userId);
            ref.invalidate(groupMembersProvider(conv.id));
            ref.invalidate(conversationsProvider);
            if (context.mounted) {
              ToastService.showSuccess(context, 'Đã xóa thành viên khỏi nhóm');
            }
          },
          onViewProfile: () {
            Navigator.pop(context);
            context.push('/profile/${member.userId}');
          },
          onDirectMessage: () async {
            Navigator.pop(context);
            final chatRepo = ref.read(chatRepositoryProvider);
            final directConv = await chatRepo.getOrCreateConversation(member.userId);
            if (context.mounted) {
              context.push('/chat/${directConv.id}');
            }
          },
        ),
      ),
    );
  }

  void _showAddMemberModal(BuildContext context, WidgetRef ref, dynamic conv) {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddMemberModalSheet(conv: conv, currentUserId: currentUserId),
    );
  }

  void _confirmLeaveGroup(BuildContext context, WidgetRef ref, dynamic conv, bool isOwner, List<ConversationMemberModel> members) {
    // Owner must transfer ownership first if there are other members
    if (isOwner) {
      final others = members.where((m) => m.userId != (ref.read(currentUserIdProvider) ?? ''));
      if (others.isNotEmpty) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Bạn là Trưởng nhóm'),
            content: const Text(
                'Bạn cần chuyển quyền Trưởng nhóm cho thành viên khác trước khi rời nhóm.'),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('Đã hiểu'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
        return;
      }
    }
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Rời khỏi nhóm?'),
        content: const Text('Bạn có chắc chắn muốn rời khỏi nhóm trò chuyện này không?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Hủy'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              final repo = ref.read(chatRepositoryProvider);
              Navigator.pop(ctx);
              ToastService.showInfo(context, 'Đang rời khỏi nhóm...');
              try {
                await repo.leaveGroup(conv.id);
                if (context.mounted) {
                  ref.invalidate(conversationsProvider);
                  context.go('/chat');
                  ToastService.showSuccess(context, 'Đã rời khỏi nhóm');
                }
              } catch (e) {
                if (context.mounted) {
                  ToastService.showError(context, 'Lỗi rời nhóm: $e');
                }
              }
            },
            child: const Text('Rời nhóm'),
          ),
        ],
      ),
    );
  }

  void _confirmDissolveGroup(BuildContext context, WidgetRef ref, dynamic conv) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Giải tán nhóm trò chuyện?'),
        content: const Text('Thao tác này sẽ xóa toàn bộ nhóm và tin nhắn đối với tất cả thành viên.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Hủy'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              final repo = ref.read(chatRepositoryProvider);
              Navigator.pop(ctx);
              ToastService.showInfo(context, 'Đang giải tán nhóm...');
              try {
                await repo.dissolveGroup(conv.id);
                if (context.mounted) {
                  ref.invalidate(conversationsProvider);
                  context.go('/chat');
                  ToastService.showSuccess(context, 'Đã giải tán nhóm thành công');
                }
              } catch (e) {
                if (context.mounted) {
                  ToastService.showError(context, 'Lỗi giải tán nhóm: $e');
                }
              }
            },
            child: const Text('Giải tán'),
          ),
        ],
      ),
    );
  }

  /// Hiện dialog chọn thời gian tắt tiếng member
  void _showMuteDurationPicker(
    BuildContext context,
    WidgetRef ref,
    String conversationId,
    ConversationMemberModel member,
  ) {
    Navigator.pop(context);
    final name = member.profile?.displayName ?? 'Thành viên';
    final durations = [
      ('1 giờ', const Duration(hours: 1)),
      ('8 giờ', const Duration(hours: 8)),
      ('24 giờ', const Duration(hours: 24)),
      ('7 ngày', const Duration(days: 7)),
      ('Vĩnh viễn', null),
    ];

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Tắt tiếng $name'),
        content: const Text('Chọn thời gian tắt tiếng:'),
        actions: [
          ...durations.map((entry) => CupertinoDialogAction(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final until = entry.$2 != null ? DateTime.now().add(entry.$2!) : null;
                  try {
                    await ref.read(chatRepositoryProvider).muteMemberByAdmin(
                          conversationId, member.userId, mutedUntil: until);
                    ref.invalidate(groupMembersProvider(conversationId));
                    if (context.mounted) {
                      ToastService.showSuccess(context, 'Đã tắt tiếng $name (${entry.$1})');
                    }
                  } catch (e) {
                    if (context.mounted) ToastService.showError(context, 'Lỗi: $e');
                  }
                },
                child: Text(entry.$1),
              )),
          CupertinoDialogAction(
            child: const Text('Hủy'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  /// Xác nhận cấm (ban) thành viên khỏi nhóm
  Future<void> _confirmBanMember(
    BuildContext context,
    WidgetRef ref,
    String conversationId,
    ConversationMemberModel member,
  ) async {
    final name = member.profile?.displayName ?? 'Thành viên';
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Cấm $name khỏi nhóm?'),
        content: const Text('Thành viên này sẽ bị xóa và không thể tham gia lại nhóm.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Hủy'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(chatRepositoryProvider).banMember(conversationId, member.userId);
                ref.invalidate(groupMembersProvider(conversationId));
                ref.invalidate(groupBansProvider(conversationId));
                ref.invalidate(conversationsProvider);
                if (context.mounted) ToastService.showSuccess(context, 'Đã cấm $name khỏi nhóm');
              } catch (e) {
                if (context.mounted) ToastService.showError(context, 'Lỗi cấm thành viên: $e');
              }
            },
            child: const Text('Cấm'),
          ),
        ],
      ),
    );
  }

  /// Xác nhận chuyển quyền Owner sang thành viên khác
  Future<void> _confirmTransferOwnership(
    BuildContext context,
    WidgetRef ref,
    String conversationId,
    ConversationMemberModel member,
  ) async {
    final name = member.profile?.displayName ?? 'Thành viên';
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Chuyển quyền cho $name?'),
        content: Text('$name sẽ trở thành Trưởng nhóm mới. Bạn sẽ trở thành Phó nhóm.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Hủy'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(chatRepositoryProvider).transferOwnership(conversationId, member.userId);
                ref.invalidate(groupMembersProvider(conversationId));
                ref.invalidate(conversationsProvider);
                if (context.mounted) ToastService.showSuccess(context, 'Đã chuyển quyền Owner cho $name');
              } catch (e) {
                if (context.mounted) ToastService.showError(context, 'Lỗi chuyển quyền: $e');
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }
}

class _AddMemberModalSheet extends ConsumerStatefulWidget {
  final dynamic conv;
  final String currentUserId;

  const _AddMemberModalSheet({required this.conv, required this.currentUserId});

  @override
  ConsumerState<_AddMemberModalSheet> createState() => _AddMemberModalSheetState();
}

class _AddMemberModalSheetState extends ConsumerState<_AddMemberModalSheet> {
  final Set<ProfileModel> _selectedFriends = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isAdding = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final friendsAsync = ref.watch(friendsListProvider(widget.currentUserId));
    final membersAsync = ref.watch(groupMembersProvider(widget.conv.id));
    final existingMemberIds = membersAsync.valueOrNull?.map((m) => m.userId).toSet() ??
        widget.conv.members?.map((m) => m.userId).toSet() ??
        <String>{};

    final cardBgColor = isDark ? const Color(0xFF252536) : const Color(0xFFF4F6FB);
    final canAdd = _selectedFriends.isNotEmpty && !_isAdding;

    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181824) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── 1. Top Header Bar ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Hủy',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Thêm thành viên mới',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  _isAdding
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CupertinoActivityIndicator(),
                        )
                      : AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            gradient: canAdd
                                ? const LinearGradient(
                                    colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: canAdd
                                ? null
                                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15)),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: canAdd
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF007AFF).withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: canAdd ? _handleAddMembers : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                child: Text(
                                  _selectedFriends.isNotEmpty ? 'Thêm (${_selectedFriends.length})' : 'Thêm',
                                  style: TextStyle(
                                    color: canAdd ? Colors.white : theme.hintColor.withValues(alpha: 0.5),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.2)),

            // ── 2. Search Field ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: 'Tìm kiếm bạn bè...',
                  placeholderStyle: TextStyle(color: theme.hintColor, fontSize: 14),
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 15),
                  backgroundColor: isDark ? const Color(0xFF252536) : const Color(0xFFF0F2F6),
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
              ),
            ),

            // ── 3. Horizontal Selected Chips ────────────────────────────────
            if (_selectedFriends.isNotEmpty) ...[
              Container(
                height: 80,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _selectedFriends.length,
                  itemBuilder: (context, idx) {
                    final friend = _selectedFriends.elementAt(idx);
                    return Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppAvatar(
                                imageUrl: friend.avatarUrl,
                                name: friend.displayName,
                                radius: 22,
                              ),
                              const SizedBox(height: 3),
                              SizedBox(
                                width: 50,
                                child: Text(
                                  friend.displayName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedFriends.remove(friend)),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.15)),
            ],

            // ── 4. Friends List ───────────────────────────────────────────────
            Expanded(
              child: friendsAsync.when(
                data: (friendsList) {
                  final availableFriends = friendsList.where((f) {
                    if (existingMemberIds.contains(f.id)) return false;
                    if (_searchQuery.isEmpty) return true;
                    final name = f.displayName.toLowerCase();
                    final username = f.username.toLowerCase();
                    return name.contains(_searchQuery) || username.contains(_searchQuery);
                  }).toList();

                  if (availableFriends.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.person_3, size: 48, color: theme.hintColor.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty ? 'Không tìm thấy bạn bè phù hợp' : 'Tất cả bạn bè đã ở trong nhóm',
                            style: TextStyle(color: theme.hintColor, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: availableFriends.length,
                    itemBuilder: (ctx, idx) {
                      final friend = availableFriends[idx];
                      final isSelected = _selectedFriends.contains(friend);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08)
                              : cardBgColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: AppAvatar(imageUrl: friend.avatarUrl, name: friend.displayName, radius: 22),
                          title: Text(
                            friend.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Text(
                            '@${friend.username}',
                            style: TextStyle(fontSize: 12, color: theme.hintColor),
                          ),
                          trailing: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                                    )
                                  : null,
                              color: isSelected ? null : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : (isDark ? Colors.white38 : Colors.black26),
                                width: 1.8,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 15, color: Colors.white)
                                : null,
                          ),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedFriends.remove(friend);
                              } else {
                                _selectedFriends.add(friend);
                              }
                            });
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CupertinoActivityIndicator()),
                error: (err, _) => Center(child: Text('Lỗi: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAddMembers() async {
    if (_selectedFriends.isEmpty || _isAdding) return;

    setState(() => _isAdding = true);
    try {
      final userIds = _selectedFriends.map((f) => f.id).toList();
      await ref.read(chatRepositoryProvider).addGroupMembers(widget.conv.id, userIds);
      ref.invalidate(conversationsProvider);
      ref.invalidate(groupMembersProvider(widget.conv.id));
      if (mounted) {
        Navigator.pop(context);
        ToastService.showSuccess(context, 'Đã thêm ${_selectedFriends.length} thành viên mới vào nhóm!');
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError(context, 'Lỗi thêm thành viên: $e');
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }
}

class MemberPopupMenuContent extends StatelessWidget {
  final ConversationMemberModel member;
  final bool isCoAdmin;
  final bool isGroupAdmin;
  final bool isOwner;
  final bool isMe;
  final VoidCallback onToggleCoAdmin;
  final VoidCallback onRemoveMember;
  final VoidCallback onViewProfile;
  final VoidCallback onDirectMessage;
  final VoidCallback? onMuteMember;
  final VoidCallback? onBanMember;
  final VoidCallback? onTransferOwnership;

  const MemberPopupMenuContent({
    super.key,
    required this.member,
    required this.isCoAdmin,
    required this.isGroupAdmin,
    required this.isOwner,
    required this.isMe,
    required this.onToggleCoAdmin,
    required this.onRemoveMember,
    required this.onViewProfile,
    required this.onDirectMessage,
    this.onMuteMember,
    this.onBanMember,
    this.onTransferOwnership,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final containerColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;

    final List<_GridMemberActionItem> actionItems = [
      if (!isMe)
        _GridMemberActionItem(
          icon: CupertinoIcons.chat_bubble_fill,
          label: 'Nhắn tin',
          onTap: onDirectMessage,
          iconColor: Colors.blue,
        ),
      _GridMemberActionItem(
        icon: CupertinoIcons.person_crop_circle,
        label: 'Trang cá nhân',
        onTap: onViewProfile,
        iconColor: Colors.teal,
      ),
      // Promote/demote to co-admin — owner only
      if (isOwner && !isMe && !member.isOwner)
        _GridMemberActionItem(
          icon: isCoAdmin ? CupertinoIcons.star_slash : CupertinoIcons.star_fill,
          label: isCoAdmin ? 'Gỡ phó nhóm' : 'Thăng phó nhóm',
          onTap: onToggleCoAdmin,
          iconColor: Colors.purpleAccent,
        ),
      // Mute member — owner/admin
      if (onMuteMember != null)
        _GridMemberActionItem(
          icon: member.isEffectivelyMutedByAdmin
              ? CupertinoIcons.speaker_2_fill
              : CupertinoIcons.speaker_slash_fill,
          label: member.isEffectivelyMutedByAdmin ? 'Bỏ tắt tiếng' : 'Tắt tiếng',
          onTap: onMuteMember!,
          iconColor: Colors.orange,
        ),
      // Remove from group — owner/admin
      if (isGroupAdmin && !isMe && !member.isOwner)
        _GridMemberActionItem(
          icon: CupertinoIcons.person_badge_minus,
          label: 'Xóa khỏi nhóm',
          onTap: onRemoveMember,
          iconColor: Colors.red,
          isDestructive: true,
        ),
      // Transfer ownership — owner only
      if (onTransferOwnership != null)
        _GridMemberActionItem(
          icon: CupertinoIcons.checkmark_shield_fill,
          label: 'Chuyển Owner',
          onTap: onTransferOwnership!,
          iconColor: Colors.amber,
        ),
      // Ban member — owner only
      if (onBanMember != null)
        _GridMemberActionItem(
          icon: CupertinoIcons.xmark_shield_fill,
          label: 'Cấm vĩnh viễn',
          onTap: onBanMember!,
          iconColor: Colors.deepOrange,
          isDestructive: true,
        ),
    ];

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 14,
          alignment: WrapAlignment.start,
          children: actionItems.map((item) {
            return SizedBox(
              width: 58,
              child: GestureDetector(
                onTap: item.onTap,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: item.isDestructive
                            ? Colors.red.withValues(alpha: 0.12)
                            : item.iconColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item.icon,
                        color: item.isDestructive ? Colors.red : item.iconColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _GridMemberActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final bool isDestructive;

  const _GridMemberActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.iconColor,
    this.isDestructive = false,
  });
}

