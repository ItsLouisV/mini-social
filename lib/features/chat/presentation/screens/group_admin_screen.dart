import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/toast_service.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../providers/chat_provider.dart';

/// Màn hình quản lý quyền nhóm (cho Owner/Admin).
/// Route: /chat/:conversationId/admin
class GroupAdminScreen extends ConsumerWidget {
  final String conversationId;

  const GroupAdminScreen({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF6F8FA);
    final cardBgColor = isDark ? const Color(0xFF1E1E2F) : Colors.white;
    final dividerColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05);

    final convAsync = ref.watch(conversationsProvider);
    final perms = ref.watch(groupPermissionsProvider(conversationId));
    final myMember = ref.watch(groupMemberMeProvider(conversationId));

    if (perms == null || myMember == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CupertinoActivityIndicator()),
      );
    }

    final conv = convAsync.valueOrNull?.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => throw Exception('Conversation not found'),
    );

    if (conv == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: Text('Không tìm thấy nhóm')),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Quản lý nhóm',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.2),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(CupertinoIcons.left_chevron, color: theme.colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ── Owner-only section ─────────────────────────────────────────────
          if (perms.isOwner) ...[
            _buildSectionHeader('CHẾ ĐỘ NHÓM'),
            _buildCardContainer(
              cardBgColor,
              children: [
                _buildSwitchTile(
                  icon: CupertinoIcons.lock_shield_fill,
                  gradientColors: [Colors.deepPurple, Colors.indigo],
                  title: 'Chỉ admin nhắn tin',
                  subtitle: 'Thành viên thường không thể gửi tin nhắn',
                  value: conv.adminOnlyMessaging,
                  onChanged: (val) async {
                    HapticFeedback.lightImpact();
                    try {
                      await ref
                          .read(chatRepositoryProvider)
                          .setAdminOnlyMessaging(conversationId, enabled: val);
                      ref.invalidate(conversationsProvider);
                    } catch (e) {
                      if (context.mounted) ToastService.showError(context, 'Lỗi: $e');
                    }
                  },
                  cardBgColor: cardBgColor,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('QUYỀN THÀNH VIÊN'),
            _buildCardContainer(
              cardBgColor,
              children: [
                _buildPermissionToggle(
                  context: context,
                  ref: ref,
                  cardBgColor: cardBgColor,
                  dividerColor: dividerColor,
                  icon: CupertinoIcons.person_badge_plus,
                  gradientColors: [Colors.teal, Colors.green],
                  title: 'Mời thành viên',
                  subtitle: 'Thành viên có thể thêm người vào nhóm',
                  value: conv.allowMemberInvite,
                  permissionKey: 'allow_member_invite',
                  showDivider: true,
                ),
                _buildPermissionToggle(
                  context: context,
                  ref: ref,
                  cardBgColor: cardBgColor,
                  dividerColor: dividerColor,
                  icon: CupertinoIcons.pin_fill,
                  gradientColors: [Colors.amber, Colors.orange],
                  title: 'Ghim tin nhắn',
                  subtitle: 'Thành viên có thể ghim / bỏ ghim tin nhắn',
                  value: conv.allowMemberPin,
                  permissionKey: 'allow_member_pin',
                  showDivider: true,
                ),
                _buildPermissionToggle(
                  context: context,
                  ref: ref,
                  cardBgColor: cardBgColor,
                  dividerColor: dividerColor,
                  icon: CupertinoIcons.at,
                  gradientColors: [Colors.blue, Colors.cyan],
                  title: '@all mention',
                  subtitle: 'Thành viên có thể dùng @all để nhắc cả nhóm',
                  value: conv.allowMemberMentionAll,
                  permissionKey: 'allow_member_mention_all',
                  showDivider: true,
                ),
                _buildPermissionToggle(
                  context: context,
                  ref: ref,
                  cardBgColor: cardBgColor,
                  dividerColor: dividerColor,
                  icon: CupertinoIcons.pencil_circle_fill,
                  gradientColors: [Colors.pinkAccent, Colors.purple],
                  title: 'Chỉnh sửa thông tin nhóm',
                  subtitle: 'Thành viên có thể đổi tên, ảnh, mô tả nhóm',
                  value: conv.allowMemberEditInfo,
                  permissionKey: 'allow_member_edit_info',
                  showDivider: false,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // ── Muted members ──────────────────────────────────────────────────
          _buildSectionHeader('THÀNH VIÊN BỊ TẮT TIẾNG'),
          _MutedMembersList(
            conversationId: conversationId,
            cardBgColor: cardBgColor,
            dividerColor: dividerColor,
            isOwner: perms.isOwner,
          ),
          const SizedBox(height: 24),

          // ── Banned members (owner only) ────────────────────────────────────
          if (perms.isOwner) ...[
            _buildSectionHeader('THÀNH VIÊN BỊ CẤM'),
            _BannedMembersList(
              conversationId: conversationId,
              cardBgColor: cardBgColor,
              dividerColor: dividerColor,
            ),
          ],
        ],
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
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required List<Color> gradientColors,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color cardBgColor,
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
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: CupertinoSwitch(value: value, onChanged: onChanged),
    );
  }

  Widget _buildPermissionToggle({
    required BuildContext context,
    required WidgetRef ref,
    required Color cardBgColor,
    required Color dividerColor,
    required IconData icon,
    required List<Color> gradientColors,
    required String title,
    required String subtitle,
    required bool value,
    required String permissionKey,
    required bool showDivider,
  }) {
    return Column(
      children: [
        ListTile(
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
          title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          trailing: CupertinoSwitch(
            value: value,
            onChanged: (val) async {
              HapticFeedback.lightImpact();
              try {
                await ref.read(chatRepositoryProvider).setMemberPermission(
                      conversationId,
                      permission: permissionKey,
                      value: val,
                    );
                ref.invalidate(conversationsProvider);
              } catch (e) {
                if (context.mounted) ToastService.showError(context, 'Lỗi: $e');
              }
            },
          ),
        ),
        if (showDivider)
          Divider(height: 0.5, thickness: 0.5, color: dividerColor, indent: 56),
      ],
    );
  }
}

// ── Muted members widget ────────────────────────────────────────────────────

class _MutedMembersList extends ConsumerWidget {
  final String conversationId;
  final Color cardBgColor;
  final Color dividerColor;
  final bool isOwner;

  const _MutedMembersList({
    required this.conversationId,
    required this.cardBgColor,
    required this.dividerColor,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(groupMembersProvider(conversationId));
    final mutedMembers = membersAsync.valueOrNull
            ?.where((m) => m.isEffectivelyMutedByAdmin)
            .toList() ??
        [];

    if (mutedMembers.isEmpty) {
      return _emptyCard(cardBgColor, 'Không có thành viên nào đang bị tắt tiếng');
    }

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
        children: mutedMembers.asMap().entries.map((entry) {
          final idx = entry.key;
          final m = entry.value;
          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: AppAvatar(
                  imageUrl: m.profile?.avatarUrl,
                  name: m.profile?.displayName ?? 'Thành viên',
                  radius: 20,
                ),
                title: Text(
                  m.profile?.displayName ?? 'Thành viên',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  m.mutedUntil != null
                      ? 'Hết hạn: ${_formatDate(m.mutedUntil!)}'
                      : 'Vĩnh viễn',
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
                trailing: isOwner
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text(
                          'Bỏ tắt',
                          style: TextStyle(color: AppColors.primary, fontSize: 13),
                        ),
                        onPressed: () async {
                          try {
                            await ref
                                .read(chatRepositoryProvider)
                                .unmuteMemberByAdmin(conversationId, m.userId);
                            ref.invalidate(groupMembersProvider(conversationId));
                            if (context.mounted) {
                              ToastService.showSuccess(context,
                                  'Đã bỏ tắt tiếng ${m.profile?.displayName ?? "thành viên"}');
                            }
                          } catch (e) {
                            if (context.mounted) ToastService.showError(context, 'Lỗi: $e');
                          }
                        },
                      )
                    : null,
              ),
              if (idx < mutedMembers.length - 1)
                Divider(height: 0.5, thickness: 0.5, color: dividerColor, indent: 56),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Banned members widget ───────────────────────────────────────────────────

class _BannedMembersList extends ConsumerWidget {
  final String conversationId;
  final Color cardBgColor;
  final Color dividerColor;

  const _BannedMembersList({
    required this.conversationId,
    required this.cardBgColor,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bansAsync = ref.watch(groupBansProvider(conversationId));

    return bansAsync.when(
      data: (bans) {
        if (bans.isEmpty) {
          return _emptyCard(cardBgColor, 'Không có thành viên nào đang bị cấm');
        }
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
            children: bans.asMap().entries.map((entry) {
              final idx = entry.key;
              final ban = entry.value;
              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: AppAvatar(
                      imageUrl: ban.userAvatarUrl,
                      name: ban.userDisplayName ?? 'Người dùng',
                      radius: 20,
                    ),
                    title: Text(
                      ban.userDisplayName ?? ban.userId,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Bị cấm: ${_formatDate(ban.bannedAt)}',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                    trailing: CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text(
                        'Bỏ cấm',
                        style: TextStyle(color: AppColors.primary, fontSize: 13),
                      ),
                      onPressed: () async {
                        try {
                          await ref
                              .read(chatRepositoryProvider)
                              .unbanMember(conversationId, ban.userId);
                          ref.invalidate(groupBansProvider(conversationId));
                          if (context.mounted) {
                            ToastService.showSuccess(
                                context,
                                'Đã bỏ lệnh cấm cho ${ban.userDisplayName ?? "thành viên"}');
                          }
                        } catch (e) {
                          if (context.mounted) ToastService.showError(context, 'Lỗi: $e');
                        }
                      },
                    ),
                  ),
                  if (idx < bans.length - 1)
                    Divider(height: 0.5, thickness: 0.5, color: dividerColor, indent: 56),
                ],
              );
            }).toList(),
          ),
        );
      },
      loading: () => const Center(
          child: Padding(
        padding: EdgeInsets.all(20),
        child: CupertinoActivityIndicator(),
      )),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Lỗi: $err', style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

Widget _emptyCard(Color cardBgColor, String message) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: cardBgColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Center(
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: Colors.grey),
        textAlign: TextAlign.center,
      ),
    ),
  );
}
