import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/providers/profile_provider.dart';

class FeedDrawer extends ConsumerWidget {
  const FeedDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final userAsync = ref.watch(authStateProvider);

    Widget buildFallback() {
      return userAsync.when(
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
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            accountEmail: Text(user?.email ?? '', style: const TextStyle(color: Colors.white70)),
          );
        },
        loading: () => const DrawerHeader(child: Center(child: CupertinoActivityIndicator())),
        error: (_, __) => const DrawerHeader(child: Center(child: Text('Lỗi tải thông tin'))),
      );
    }

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          if (currentUserId != null)
            ref.watch(profileProvider(currentUserId)).when(
              data: (profile) {
                return UserAccountsDrawerHeader(
                  decoration: BoxDecoration(
                    gradient: profile.coverUrl == null || profile.coverUrl!.isEmpty
                        ? LinearGradient(
                            colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    image: profile.coverUrl != null && profile.coverUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(profile.coverUrl!),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withOpacity(0.35),
                              BlendMode.darken,
                            ),
                          )
                        : null,
                  ),
                  currentAccountPicture: AppAvatar(
                    imageUrl: profile.avatarUrl,
                    name: profile.displayName,
                    radius: 36,
                  ),
                  accountName: Text(
                    profile.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                    ),
                  ),
                  accountEmail: Text(
                    '@${profile.username}',
                    style: const TextStyle(
                      color: Colors.white70,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                    ),
                  ),
                );
              },
              loading: () => const DrawerHeader(child: Center(child: CupertinoActivityIndicator())),
              error: (_, __) => buildFallback(),
            )
          else
            buildFallback(),
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
