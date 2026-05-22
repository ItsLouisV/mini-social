import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/domain/profile_model.dart';
import '../../providers/follow_list_provider.dart';
import '../../providers/follow_provider.dart';

class FollowListScreen extends ConsumerWidget {
  final String userId;
  final int initialIndex; // 0 for followers, 1 for following

  const FollowListScreen({
    super.key,
    required this.userId,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Kết nối',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Người theo dõi'),
              Tab(text: 'Đang theo dõi'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FollowListTab(
              provider: followersProvider(userId),
              emptyMessage: 'Chưa có người theo dõi nào',
            ),
            _FollowListTab(
              provider: followingProvider(userId),
              emptyMessage: 'Chưa theo dõi ai',
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowListTab extends ConsumerWidget {
  final ProviderListenable<AsyncValue<List<ProfileModel>>> provider;
  final String emptyMessage;

  const _FollowListTab({
    required this.provider,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(provider);

    return asyncData.when(
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Text(
              emptyMessage,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          );
        }

        return ListView.separated(
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final user = users[index];
            final isFollowingAsync = ref.watch(isFollowingProvider(user.id));

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: AppAvatar(
                imageUrl: user.avatarUrl,
                name: user.displayName,
                radius: 22,
              ),
              title: Text(user.displayName, style: AppTextStyles.titleSmall),
              subtitle: Text('@${user.username}', style: AppTextStyles.caption),
              trailing: user.id == ref.watch(currentUserIdProvider)
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Tôi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    )
                  : isFollowingAsync.when(
                      data: (isFollowing) => OutlinedButton(
                        onPressed: () {
                          ref.read(isFollowingProvider(user.id).notifier).toggleFollow();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: Size.zero,
                          side: BorderSide(
                            color: isFollowing
                                ? Theme.of(context).dividerColor
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        child: Text(
                          isFollowing ? 'Đang theo dõi' : 'Theo dõi',
                          style: TextStyle(
                            fontSize: 12,
                            color: isFollowing
                                ? Theme.of(context).hintColor
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      loading: () => const SizedBox(
                        width: 80,
                        child: LinearProgressIndicator(),
                      ),
                      error: (_, __) => const SizedBox(),
                    ),
              onTap: () => context.push('/profile/${user.id}'),
            );
          },
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }
}
