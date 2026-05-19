import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final profileAsync = ref.watch(profileProvider(currentUserId ?? ''));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final email =
        ref.watch(supabaseServiceProvider).client.auth.currentUser?.email ??
            '';

    final groupedBg =
        isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final labelColor =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);

    return CupertinoPageScaffold(
      backgroundColor: groupedBg,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: groupedBg.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.pop(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.chevron_back,
                  color: theme.colorScheme.primary, size: 18),
              const SizedBox(width: 4),
              Text(
                'Cài đặt',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        middle: const Text(
          'Tài khoản',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // ── Avatar + tên + email ─────────────────────────────
            profileAsync.when(
              data: (profile) => Column(
                children: [
                  const SizedBox(height: 12),
                  AppAvatar(
                    imageUrl: profile.avatarUrl,
                    name: profile.displayName,
                    radius: 44,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    profile.displayName,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style:
                        TextStyle(fontSize: 14, color: labelColor),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
              loading: () => const SizedBox(
                  height: 180,
                  child:
                      Center(child: CupertinoActivityIndicator())),
              error: (_, __) => const SizedBox(height: 60),
            ),

            // ── Thông tin cá nhân ────────────────────────────────
            _SectionLabel(
                label: 'THÔNG TIN CÁ NHÂN', color: labelColor),
            _SectionCard(
              bg: cardBg,
              child: Column(
                children: [
                  _IosRow(
                    icon: CupertinoIcons.person_fill,
                    iconBg: Colors.blue,
                    title: 'Chỉnh sửa hồ sơ',
                    onTap: () => context.push('/profile/edit'),
                  ),
                  _RowDivider(color: theme.dividerColor),
                  _IosRow(
                    icon: CupertinoIcons.at,
                    iconBg: const Color(0xFF30B0C7),
                    title: 'Tên người dùng',
                    showChevron: false,
                    trailing: _ValueLabel(
                      text: profileAsync
                              .whenData((p) => '@${p.username}')
                              .valueOrNull ??
                          '',
                      color: labelColor,
                    ),
                    onTap: () => context.push('/profile/edit'),
                  ),
                ],
              ),
            ),

            // ── Đăng nhập & Bảo mật ─────────────────────────────
            _SectionLabel(
                label: 'ĐĂNG NHẬP & BẢO MẬT', color: labelColor),
            _SectionCard(
              bg: cardBg,
              child: Column(
                children: [
                  _IosRow(
                    icon: CupertinoIcons.mail_solid,
                    iconBg: Colors.redAccent,
                    title: 'Email',
                    showChevron: false,
                    trailing: _ValueLabel(
                      text: email.isNotEmpty ? email : 'Chưa có',
                      color: labelColor,
                    ),
                  ),
                  _RowDivider(color: theme.dividerColor),
                  _IosRow(
                    icon: CupertinoIcons.lock_fill,
                    iconBg: Colors.orange,
                    title: 'Đổi mật khẩu',
                    onTap: () {},
                  ),
                  _RowDivider(color: theme.dividerColor),
                  _IosRow(
                    icon: CupertinoIcons.lock_shield_fill,
                    iconBg: Colors.green,
                    title: 'Xác thực 2 bước',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            // ── Dữ liệu & Bộ nhớ ────────────────────────────────
            _SectionLabel(
                label: 'DỮ LIỆU & BỘ NHỚ', color: labelColor),
            _SectionCard(
              bg: cardBg,
              child: Column(
                children: [
                  _IosRow(
                    icon: CupertinoIcons.cloud_fill,
                    iconBg: Colors.blue.shade600,
                    title: 'Sao lưu dữ liệu',
                    onTap: () {},
                  ),
                  _RowDivider(color: theme.dividerColor),
                  _IosRow(
                    icon: CupertinoIcons.trash_fill,
                    iconBg: Colors.red.shade700,
                    title: 'Xóa tài khoản',
                    titleColor: Colors.red,
                    showChevron: false,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            // ── Đăng xuất ───────────────────────────────────────
            const SizedBox(height: 32),
            _SectionCard(
              bg: cardBg,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showLogoutDialog(context, ref),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 15),
                    child: Center(
                      child: Text(
                        'Đăng xuất',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Đăng xuất'),
        content:
            const Text('Bạn có chắc muốn đăng xuất khỏi ứng dụng?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => ctx.pop(),
            child: const Text('Huỷ'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              ctx.pop();
              ref.read(authRepositoryProvider).signOut();
              context.go('/login');
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ValueLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _ValueLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(fontSize: 15, color: color),
        overflow: TextOverflow.ellipsis,
      );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(32, 22, 16, 6),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4),
        ),
      );
}

class _SectionCard extends StatelessWidget {
  final Color bg;
  final Widget child;
  const _SectionCard({required this.bg, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class _RowDivider extends StatelessWidget {
  final Color color;
  const _RowDivider({required this.color});

  @override
  Widget build(BuildContext context) => Divider(
        height: 0.5,
        thickness: 0.5,
        indent: 54,
        color: color.withValues(alpha: 0.4),
      );
}

class _IosRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final Color? titleColor;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  const _IosRow({
    required this.icon,
    required this.iconBg,
    required this.title,
    this.titleColor,
    this.trailing,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hintColor = Theme.of(context).hintColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(7)),
                child: Icon(icon, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: titleColor ??
                        Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (showChevron)
                Icon(CupertinoIcons.chevron_forward,
                    size: 16, color: hintColor),
            ],
          ),
        ),
      ),
    );
  }
}
