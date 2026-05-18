import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';

class FeedDrawer extends ConsumerWidget {
  const FeedDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          userAsync.when(
            data: (authState) {
              final user = authState.session?.user;
              return UserAccountsDrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                currentAccountPicture: AppAvatar(
                  imageUrl: user?.userMetadata?['avatar_url'],
                  name: user?.userMetadata?['full_name'] ?? user?.email,
                  radius: 36,
                ),
                accountName: Text(
                  user?.userMetadata?['full_name'] ?? 'MiniSocial User',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                accountEmail: Text(user?.email ?? ''),
              );
            },
            loading: () => const DrawerHeader(child: Center(child: CupertinoActivityIndicator())),
            error: (_, __) => const DrawerHeader(child: Center(child: Text('Lỗi tải thông tin'))),
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.person),
            title: const Text('Trang cá nhân'),
            onTap: () {
              context.pop();
              context.push('/profile/me');
            },
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.bookmark),
            title: const Text('Đã lưu'),
            onTap: () {
              context.pop();
              // context.push('/saved');
            },
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.heart),
            title: const Text('Đã thích'),
            onTap: () {
              context.pop();
              // context.push('/liked');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(CupertinoIcons.settings),
            title: const Text('Cài đặt'),
            onTap: () {
              context.pop();
              context.push('/settings');
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListTile(
              leading: Icon(CupertinoIcons.square_arrow_left, color: Theme.of(context).colorScheme.error),
              title: Text('Đăng xuất', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () async {
                context.pop();
                await ref.read(authRepositoryProvider).signOut();
              },
            ),
          ),
        ],
      ),
    );
  }
}
