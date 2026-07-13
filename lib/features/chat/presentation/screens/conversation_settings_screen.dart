import 'dart:io' as io;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/full_screen_image_viewer.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/hidden_chat_provider.dart';
import '../widgets/passcode_dialog.dart';

class ConversationSettingsScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ConversationSettingsScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ConversationSettingsScreen> createState() => _ConversationSettingsScreenState();
}

class _ConversationSettingsScreenState extends ConsumerState<ConversationSettingsScreen> {
  final List<Map<String, dynamic>> _chatThemes = [
    {'id': 'blue', 'name': 'Cổ điển (Xanh)', 'color': Colors.blue},
    {'id': 'purple', 'name': 'Neon (Tím)', 'color': Colors.purple},
    {'id': 'orange', 'name': 'Hoàng hôn (Cam)', 'color': Colors.orange},
    {'id': 'teal', 'name': 'Lục bảo (Xanh lá)', 'color': Colors.teal},
    {'id': 'pink', 'name': 'Hoa anh đào (Hồng)', 'color': Colors.pink},
  ];

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
    final activeThemeItem = _chatThemes.firstWhere((t) => t['id'] == activeThemeId, orElse: () => _chatThemes.first);


    // Fetch shared media images from the conversation history
    final messagesAsync = ref.watch(realtimeMessagesProvider(widget.conversationId));
    final mediaMessages = messagesAsync.valueOrNull?.messages
            .where((m) => m.isImage || (m.mediaUrl != null && m.mediaUrl!.isNotEmpty))
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
        title: const Text(
          'Tùy chọn cuộc trò chuyện',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.2),
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

          final otherUser = conv.otherUser;
          final otherUserName = otherUser?.displayName ?? 'Người dùng';
          final otherUserUsername = otherUser?.username ?? '';
          final avatarUrl = otherUser?.avatarUrl;

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
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (activeThemeItem['color'] as Color).withValues(alpha: 0.4),
                              width: 3,
                            ),
                          ),
                          child: AppAvatar(
                            imageUrl: avatarUrl,
                            name: otherUserName,
                            radius: 48,
                          ),
                        ),
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
                    Text(
                      otherUserName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (otherUserUsername.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '@$otherUserUsername',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.hintColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    const Text(
                      'Đang hoạt động',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF34C759),
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
                                  onTap: () => _openSharedImage(context, msg.mediaUrl!),
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
                                        tag: msg.mediaUrl!,
                                        child: CachedNetworkImage(
                                          imageUrl: msg.mediaUrl!,
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
              const SizedBox(height: 24),

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
                              activeThemeItem['name'],
                              style: TextStyle(fontSize: 13, color: activeThemeItem['color'], fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 36,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _chatThemes.length,
                            itemBuilder: (context, idx) {
                              final item = _chatThemes[idx];
                              final isSelected = activeThemeId == item['id'];
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  ref.read(chatThemeColorProvider.notifier).setTheme(widget.conversationId, item['id']);
                                  ScaffoldMessenger.of(context).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Đã cập nhật chủ đề chat sang ${item['name']}'),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: item['color'],
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(color: isDark ? Colors.white : Colors.black87, width: 3)
                                        : null,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (item['color'] as Color).withValues(alpha: 0.3),
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
              _buildCardContainer(
                cardBgColor,
                children: [
                  _buildListTile(
                    context: context,
                    icon: CupertinoIcons.slash_circle,
                    gradientColors: [Colors.redAccent, Colors.red],
                    title: 'Chặn người dùng này',
                    titleColor: Colors.red,
                    trailing: const SizedBox.shrink(),
                    onTap: () => _confirmBlockUser(context, otherUserName),
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
              ),
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

  void _confirmBlockUser(BuildContext context, String userName) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Chặn $userName?'),
        content: const Text('Người dùng này sẽ không thể nhắn tin hoặc gọi điện cho bạn nữa.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Huỷ'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã chặn thành công $userName')),
              );
            },
            child: const Text('Chặn'),
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
}
