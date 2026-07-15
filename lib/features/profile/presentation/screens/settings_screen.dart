import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme_provider.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final profileAsync = ref.watch(profileProvider(currentUserId ?? ''));
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // iOS grouped background màu
    final groupedBg = theme.scaffoldBackgroundColor;
    final cardBg = theme.colorScheme.surface;
    final labelColor =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);

    return Scaffold(
      backgroundColor: groupedBg,
      body: CustomScrollView(
        slivers: [
          // ── Large-title iOS nav bar ──────────────────────────────────
          CupertinoSliverNavigationBar(
            transitionBetweenRoutes: false,
            largeTitle: const Text(
              'Cài đặt',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: groupedBg.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.0),
                width: 0,
              ),
            ),
          ),

          SliverSafeArea(
            top: false,
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Apple-ID style profile banner ───────────────────────
                profileAsync.when(
                  data: (profile) => _ProfileBanner(
                    profile: profile,
                    cardBg: cardBg,
                    labelColor: labelColor,
                    onTap: () => context.push('/settings/account'),
                  ),
                  loading: () => _SectionCard(
                    bg: cardBg,
                    child: const SizedBox(
                      height: 80,
                      child: Center(child: CupertinoActivityIndicator()),
                    ),
                  ),
                  error: (_, __) => const SizedBox(),
                ),

                // ── TRUY CẬP ────────────────────────────────────────────
                _SectionLabel(label: 'TRUY CẬP', color: labelColor),
                _SectionCard(
                  bg: cardBg,
                  child: Column(
                    children: [
                      _IosRow(
                        iconBg: Colors.blue,
                        icon: CupertinoIcons.person_crop_rectangle_fill,
                        title: 'Trang cá nhân',
                        onTap: () => context.push('/profile/me'),
                      ),
                      _Divider(color: theme.dividerColor),
                      _IosRow(
                        iconBg: Colors.orange,
                        icon: CupertinoIcons.person_2_fill,
                        title: 'Bạn bè',
                        onTap: () => context.push('/profile/${currentUserId ?? "me"}/friends'),
                      ),
                      _Divider(color: theme.dividerColor),
                      _IosRow(
                        iconBg: Colors.teal,
                        icon: CupertinoIcons.device_phone_portrait,
                        title: 'Thiết bị đăng nhập',
                        onTap: () => context.push('/settings/devices'),
                      ),
                      _Divider(color: theme.dividerColor),
                      _IosRow(
                        iconBg: Colors.green,
                        icon: CupertinoIcons.shield_lefthalf_fill,
                        title: 'Quyền riêng tư',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                // ── TÙY CHỈNH ───────────────────────────────────────────
                _SectionLabel(label: 'TÙY CHỈNH', color: labelColor),
                _SectionCard(
                  bg: cardBg,
                  child: Column(
                    children: [
                      _IosRow(
                        iconBg: Colors.indigo,
                        icon: CupertinoIcons.moon_fill,
                        title: 'Chế độ tối',
                        showChevron: false,
                        trailing: CupertinoSwitch(
                          activeTrackColor: theme.colorScheme.primary,
                          value: themeMode == ThemeMode.dark,
                          onChanged: (val) {
                            ref.read(themeModeProvider.notifier).setTheme(
                                val ? ThemeMode.dark : ThemeMode.light);
                          },
                        ),
                      ),
                      _Divider(color: theme.dividerColor),
                      _IosRow(
                        iconBg: Colors.redAccent,
                        icon: CupertinoIcons.bell_fill,
                        title: 'Thông báo',
                        onTap: () {},
                      ),
                      _Divider(color: theme.dividerColor),
                      _IosRow(
                        iconBg: Colors.purple,
                        icon: CupertinoIcons.globe,
                        title: 'Ngôn ngữ',
                        showChevron: false,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Tiếng Việt',
                              style: TextStyle(color: labelColor, fontSize: 15),
                            ),
                            const SizedBox(width: 6),
                            Icon(CupertinoIcons.chevron_forward,
                                size: 16, color: labelColor),
                          ],
                        ),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                // ── HỖ TRỢ ──────────────────────────────────────────────
                _SectionLabel(label: 'HỖ TRỢ', color: labelColor),
                _SectionCard(
                  bg: cardBg,
                  child: Column(
                    children: [
                      _IosRow(
                        iconBg: Colors.lightBlue,
                        icon: CupertinoIcons.question_circle_fill,
                        title: 'Trợ giúp & Hỗ trợ',
                        onTap: () {},
                      ),
                      _Divider(color: theme.dividerColor),
                      _IosRow(
                        iconBg: Colors.teal,
                        icon: CupertinoIcons.info_circle_fill,
                        title: 'Về MiniSocial',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                // ── ĐĂNG XUẤT ───────────────────────────────────────────
                const SizedBox(height: 32),
                _SectionCard(
                  bg: cardBg,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onPressed: () => _showLogoutDialog(context, ref),
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

                // ── Version footer ───────────────────────────────────────
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'MiniSocial • Phiên bản 1.0.0',
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi ứng dụng?'),
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
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Apple-ID Style Profile Banner
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileBanner extends StatelessWidget {
  final dynamic profile;
  final Color cardBg;
  final Color labelColor;
  final VoidCallback onTap;

  const _ProfileBanner({
    required this.profile,
    required this.cardBg,
    required this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                AppAvatar(
                  imageUrl: profile.avatarUrl,
                  name: profile.displayName,
                  radius: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Tài khoản, Bảo mật & Dữ liệu',
                        style: TextStyle(
                          fontSize: 13,
                          color: labelColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 16,
                  color: labelColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 22, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Color bg;
  final Widget child;
  const _SectionCard({required this.bg, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;
  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: 54,
      endIndent: 0,
      color: color.withValues(alpha: 0.4),
    );
  }
}

class _IosRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  const _IosRow({
    required this.icon,
    required this.iconBg,
    required this.title,
    this.trailing,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hintColor = Theme.of(context).hintColor;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

            // Trailing / chevron
            trailing ??
                (showChevron
                    ? Icon(CupertinoIcons.chevron_forward,
                        size: 16, color: hintColor)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
