import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';


import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../social/providers/follow_provider.dart';
import '../../domain/profile_model.dart';
import '../../providers/profile_provider.dart';
import '../widgets/profile_posts_grid.dart';

class ProfileScreen extends ConsumerWidget {
  final String userId;
  final bool isMe;

  const ProfileScreen({
    super.key,
    required this.userId,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider(userId));
    final currentUserId = ref.watch(currentUserIdProvider);
    final isMine = isMe || currentUserId == userId;

    return Scaffold(
      body: profileAsync.when(
        data: (profile) => _buildBody(context, ref, profile, isMine),
        loading: () => _buildShimmer(context),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(profileProvider(userId)),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, ProfileModel profile,
      bool isMine) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(context, ref, profile, isMine),
          ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _SliverAppBarDelegate(
            minHeight: 50.0,
            maxHeight: 50.0,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: const Text(
                'Bài viết',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ),
        ProfilePostsGrid(userId: profile.id),
      ],
    ),
  );
}

  Widget _buildHeader(BuildContext context, WidgetRef ref, ProfileModel profile, bool isMine) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            SizedBox(
              height: 200,
              width: double.infinity,
              child: profile.coverUrl != null && profile.coverUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: profile.coverUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: theme.colorScheme.surfaceVariant),
                      errorWidget: (_, __, ___) => Container(color: theme.colorScheme.surfaceVariant),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
            ),
            
            // Profile Info
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(profile.displayName, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('@${profile.username}', style: TextStyle(fontSize: 15, color: theme.hintColor)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      isMine
                          ? OutlinedButton(
                              onPressed: () => context.push('/profile/edit'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text('Chỉnh sửa hồ sơ', style: TextStyle(fontWeight: FontWeight.bold)),
                            )
                          : _buildFollowButton(context, ref, profile),
                    ],
                  ),
                  if (profile.bio?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Text(profile.bio!, style: theme.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 16),
                  
                  // Inline Stats
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${profile.followersCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 4),
                          Text('Người theo dõi', style: TextStyle(color: theme.hintColor, fontSize: 15)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${profile.followingCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 4),
                          Text('Đang theo dõi', style: TextStyle(color: theme.hintColor, fontSize: 15)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // Avatar (Overlapping cover)
        Positioned(
          top: 200 - 46, // Cover height minus avatar radius
          left: 16,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.scaffoldBackgroundColor, width: 4),
            ),
            child: AppAvatar(
              imageUrl: profile.avatarUrl,
              name: profile.displayName,
              radius: 46,
            ),
          ),
        ),
        
        // Floating Back Button
        if (context.canPop())
          Positioned(
            top: topPadding > 0 ? topPadding + 8 : 16, // Adjust for safe area
            left: 8,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.chevron_back, size: 20, color: Colors.white),
              ),
              onPressed: () => context.pop(),
            ),
          ),
      ],
    );
  }

  Widget _buildFollowButton(
      BuildContext context, WidgetRef ref, ProfileModel profile) {
    final isFollowingAsync = ref.watch(isFollowingProvider(profile.id));
    return isFollowingAsync.when(
      data: (isFollowing) => ElevatedButton(
        onPressed: () {
          if (isFollowing) {
            ref.read(followActionsProvider.notifier).unfollow(profile.id);
          } else {
            ref.read(followActionsProvider.notifier).follow(profile.id);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isFollowing ? Theme.of(context).dividerColor.withValues(alpha: 0.1) : Theme.of(context).colorScheme.primary,
          foregroundColor: isFollowing ? Theme.of(context).textTheme.bodyLarge?.color : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          isFollowing ? 'Đang theo dõi' : 'Theo dõi',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      loading: () => const SizedBox(width: 100, child: Center(child: CupertinoActivityIndicator())),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Container(height: 200, color: Theme.of(context).cardColor),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    width: 88, height: 88, decoration: BoxDecoration(
                  shape: BoxShape.circle, color: Theme.of(context).cardColor)),
                const SizedBox(height: 12),
                Container(width: 160, height: 20, color: Theme.of(context).cardColor),
                const SizedBox(height: 8),
                Container(width: 100, height: 14, color: Theme.of(context).cardColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => math.max(maxHeight, minHeight);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
