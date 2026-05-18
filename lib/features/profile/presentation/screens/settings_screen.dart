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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Using standard background
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Cài đặt', style: TextStyle(fontWeight: FontWeight.bold)),
            elevation: 0,
            backgroundColor: theme.scaffoldBackgroundColor,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                children: [
                  // Profile Banner (Apple ID style)
                  profileAsync.when(
                    data: (profile) => _buildSection(
                      context,
                      null,
                      [
                        InkWell(
                          onTap: () => context.push('/settings/account'),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                AppAvatar(
                                  imageUrl: profile.avatarUrl,
                                  name: profile.displayName,
                                  radius: 30,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(profile.displayName,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text('Tài khoản, Bảo mật & Dữ liệu',
                                          style: TextStyle(
                                              fontSize: 13, color: theme.hintColor)),
                                    ],
                                  ),
                                ),
                                Icon(CupertinoIcons.chevron_forward,
                                    size: 18, color: theme.hintColor),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    loading: () => const Center(child: CupertinoActivityIndicator()),
                    error: (_, __) => const SizedBox(),
                  ),

                  _buildSection(
                    context,
                    'Truy cập',
                    [
                      _buildSettingsItem(
                        context,
                        icon: CupertinoIcons.person_crop_rectangle_fill,
                        iconColor: Colors.blue,
                        title: 'Trang cá nhân',
                        onTap: () => context.push('/profile/me'),
                      ),
                      _buildSettingsItem(
                        context,
                        icon: CupertinoIcons.shield_lefthalf_fill,
                        iconColor: Colors.green,
                        title: 'Quyền riêng tư',
                        onTap: () {},
                      ),
                    ],
                  ),

                  _buildSection(
                    context,
                    'Tùy chỉnh',
                    [
                      _buildSettingsItem(
                        context,
                        icon: CupertinoIcons.moon_fill,
                        iconColor: Colors.indigo,
                        title: 'Chế độ tối',
                        trailing: CupertinoSwitch(
                          activeTrackColor: theme.colorScheme.primary,
                          value: themeMode == ThemeMode.dark,
                          onChanged: (val) {
                            ref.read(themeModeProvider.notifier).setTheme(
                                val ? ThemeMode.dark : ThemeMode.light);
                          },
                        ),
                      ),
                      _buildSettingsItem(
                        context,
                        icon: CupertinoIcons.bell_fill,
                        iconColor: Colors.redAccent,
                        title: 'Thông báo',
                        onTap: () {},
                      ),
                      _buildSettingsItem(
                        context,
                        icon: CupertinoIcons.globe,
                        iconColor: Colors.purple,
                        title: 'Ngôn ngữ',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Tiếng Việt', style: TextStyle(color: theme.hintColor)),
                            const SizedBox(width: 8),
                            Icon(CupertinoIcons.chevron_forward, size: 18, color: theme.hintColor),
                          ],
                        ),
                        showChevron: false,
                        onTap: () {},
                      ),
                    ],
                  ),

                  _buildSection(
                    context,
                    'Hỗ trợ',
                    [
                      _buildSettingsItem(
                        context,
                        icon: CupertinoIcons.question_circle_fill,
                        iconColor: Colors.lightBlue,
                        title: 'Trợ giúp & Hỗ trợ',
                        onTap: () {},
                      ),
                      _buildSettingsItem(
                        context,
                        icon: CupertinoIcons.info_circle_fill,
                        iconColor: Colors.teal,
                        title: 'Về MiniSocial',
                        onTap: () {},
                      ),
                    ],
                  ),

                  _buildSection(
                    context,
                    null,
                    [
                      _buildSettingsItem(
                        context,
                        icon: CupertinoIcons.square_arrow_right_fill,
                        iconColor: theme.colorScheme.error,
                        title: 'Đăng xuất',
                        titleColor: theme.colorScheme.error,
                        showChevron: false,
                        onTap: () => _showLogoutDialog(context, ref),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      'Phiên bản 1.0.0\nMiniSocial',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.hintColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String? title, List<Widget> children) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 6, top: 24),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                color: theme.hintColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 52,
                    endIndent: 0,
                    color: theme.dividerColor.withValues(alpha: 0.5),
                  ),
              ]
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    Color? titleColor,
    Widget? trailing,
    bool showChevron = true,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: iconColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: titleColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing ??
          (showChevron
              ? Icon(CupertinoIcons.chevron_forward,
                  size: 18, color: Theme.of(context).hintColor)
              : null),
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
            child: const Text('Hủy'),
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
