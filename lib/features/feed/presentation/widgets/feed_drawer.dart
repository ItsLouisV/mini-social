import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/localization/locale_provider.dart';

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
            title: Text(AppTranslations.tr(ref, 'profile')),
            onTap: () {
              context.pop();
              context.push('/profile/me');
            },
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.bookmark),
            title: Text(AppTranslations.tr(ref, 'saved')),
            onTap: () {
              context.pop();
            },
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.heart),
            title: Text(AppTranslations.tr(ref, 'liked_posts')),
            onTap: () {
              context.pop();
            },
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.trash, color: Colors.orangeAccent),
            title: Text(AppTranslations.tr(ref, 'trash')),
            onTap: () {
              context.pop();
              context.push('/trash');
            },
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.globe, color: Colors.purpleAccent),
            title: Text(AppTranslations.tr(ref, 'language')),
            trailing: Text(
              ref.watch(appLanguageProvider).flag,
              style: const TextStyle(fontSize: 18),
            ),
            onTap: () {
              context.pop();
              context.push('/settings/language');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(CupertinoIcons.settings),
            title: Text(AppTranslations.tr(ref, 'account_settings')),
            onTap: () {
              context.pop();
              context.push('/settings/account');
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListTile(
              leading: Icon(CupertinoIcons.square_arrow_left, color: Theme.of(context).colorScheme.error),
              title: Text(AppTranslations.tr(ref, 'logout'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
