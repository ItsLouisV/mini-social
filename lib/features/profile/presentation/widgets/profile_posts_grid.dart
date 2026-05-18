import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../providers/profile_provider.dart';
import '../../../feed/domain/post_model.dart';
import '../../../feed/presentation/widgets/post_card.dart';

import '../../../auth/providers/auth_provider.dart';

class ProfilePostsGrid extends ConsumerWidget {
  final String userId;

  const ProfilePostsGrid({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(userPostsProvider(userId));
    final currentUserId = ref.watch(currentUserIdProvider);

    return postsAsync.when(
      data: (postsData) {
        if (postsData.isEmpty) {
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

        final posts = postsData.map((e) => PostModel.fromJson(e)).toList();

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final post = posts[index];
              return Column(
                children: [
                  PostCard(post: post, currentUserId: currentUserId ?? ''),
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
