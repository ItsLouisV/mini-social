import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../providers/profile_provider.dart';
import '../../../feed/presentation/widgets/post_card.dart';

import '../../../auth/providers/auth_provider.dart';

class ProfilePostsGrid extends ConsumerWidget {
  final String userId;

  const ProfilePostsGrid({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(userPostsProvider(userId));
    final currentUserId = ref.watch(currentUserIdProvider);
    final profile = ref.watch(profileProvider(userId)).valueOrNull;
    final displayName = profile?.displayName ?? 'người dùng này';

    return postsAsync.when(
      data: (userPostsData) {
        if (userPostsData.posts.isEmpty) {
          // Trường hợp 1: Có bài viết nhưng bị ẩn do chế độ Bạn bè / Người theo dõi
          if (userPostsData.hiddenFriendsPostsCount > 0 ||
              (!userPostsData.isFriendOrFollower && userPostsData.totalRawPosts > 0)) {
            return SliverToBoxAdapter(
              child: SizedBox(
                height: 240,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.lock_fill,
                            size: 38,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Hãy kết bạn với $displayName để xem bài viết của họ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Các bài viết của $displayName đang ở chế độ Bạn bè',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          // Trường hợp 2: Thật sự chưa có bài viết nào được đăng
          return SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.photo_on_rectangle,
                        size: 48, color: Theme.of(context).hintColor),
                    const SizedBox(height: 12),
                    Text('Chưa có bài viết nào',
                        style: TextStyle(color: Theme.of(context).hintColor)),
                  ],
                ),
              ),
            ),
          );
        }

        final posts = userPostsData.posts;

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final post = posts[index];
              return Column(
                children: [
                  PostCard(post: post, currentUserId: currentUserId ?? '', heroScope: 'profile'),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                  ),
                ],
              );
            },
            childCount: posts.length,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: Center(child: CupertinoActivityIndicator()),
        ),
      ),
      error: (e, _) => const SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: Center(child: Text('Lỗi tải bài viết')),
        ),
      ),
    );
  }
}
