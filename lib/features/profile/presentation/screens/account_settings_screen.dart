import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../../../core/services/supabase_service.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final profileAsync = ref.watch(profileProvider(currentUserId ?? ''));
    final theme = Theme.of(context);
    
    // Get email from Supabase
    final email = ref.watch(supabaseServiceProvider).client.auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Tài khoản', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Large Avatar & Info
          profileAsync.when(
            data: (profile) => Column(
              children: [
                AppAvatar(
                  imageUrl: profile.avatarUrl,
                  name: profile.displayName,
                  radius: 50,
                ),
                const SizedBox(height: 16),
                Text(
                  profile.displayName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(fontSize: 15, color: theme.hintColor),
                ),
                const SizedBox(height: 32),
              ],
            ),
            loading: () => const SizedBox(height: 150, child: Center(child: CupertinoActivityIndicator())),
            error: (_, __) => const SizedBox(height: 150),
          ),

          _buildSection(
            context,
            null,
            [
              _buildSettingsItem(
                context,
                title: 'Thông tin cá nhân',
                onTap: () => context.push('/profile/edit'),
              ),
              _buildSettingsItem(
                context,
                title: 'Đăng nhập & Bảo mật',
                onTap: () {},
              ),
              _buildSettingsItem(
                context,
                title: 'Thanh toán & Giao hàng',
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
                title: 'Đăng xuất',
                titleColor: theme.colorScheme.error,
                showChevron: false,
                isCenter: true,
                onTap: () => _showLogoutDialog(context, ref),
              ),
            ],
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
          const SizedBox(height: 24),
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
                    indent: 16,
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
    required String title,
    Color? titleColor,
    bool showChevron = true,
    bool isCenter = false,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        title,
        textAlign: isCenter ? TextAlign.center : TextAlign.left,
        style: TextStyle(
          fontSize: 16,
          color: titleColor,
          fontWeight: FontWeight.w400,
        ),
      ),
      trailing: showChevron
          ? Icon(CupertinoIcons.chevron_forward, size: 18, color: Theme.of(context).hintColor)
          : null,
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
              context.go('/login');
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}
