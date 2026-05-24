import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/utils/notifications.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../widgets/post_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedPostsProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            floating: true,
            snap: true,
            forceElevated: innerBoxIsScrolled,
            backgroundColor:
                theme.scaffoldBackgroundColor.withValues(alpha: 0.92),
            elevation: 0,
            scrolledUnderElevation: 0.5,
            shadowColor: theme.dividerColor.withValues(alpha: 0.3),
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 52,
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'MiniSocial',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            leading: IconButton(
              icon: Icon(
                CupertinoIcons.bars,
                color: theme.textTheme.bodyLarge?.color,
              ),
              onPressed: () =>
                  const OpenDrawerNotification().dispatch(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  CupertinoIcons.search,
                  color: theme.textTheme.bodyLarge?.color,
                ),
                onPressed: () => context.push('/search'),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ],
        body: feedAsync.when(
          data: (posts) {
            if (posts.isEmpty) {
              return const EmptyStateWidget(
                icon: CupertinoIcons.doc_text,
                title: 'Feed trống',
                subtitle: 'Hãy theo dõi thêm người để xem bài viết của họ',
              );
            }

            return RefreshIndicator.adaptive(
              onRefresh: () async => ref.invalidate(feedPostsProvider),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: posts.length,
                itemBuilder: (context, index) => PostCard(
                  post: posts[index],
                  currentUserId: currentUserId ?? '',
                ),
              ),
            );
          },
          loading: () => _buildShimmer(context),
          error: (e, _) => AppErrorWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(feedPostsProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: ListView.builder(
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 320,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
