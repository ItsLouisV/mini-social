import 'dart:math' show pi;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/notifications.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../providers/feed_provider.dart';
import '../widgets/people_you_may_know_carousel.dart';
import '../widgets/post_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedPostsProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final scrollController = ref.watch(feedScrollControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: NestedScrollView(
        controller: scrollController,
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
                  'Viora',
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

            final showPymk = currentUserId != null && currentUserId.isNotEmpty;
            final pymkPosition = posts.length >= 2 ? 3 : posts.length + 1;
            final totalItemCount = posts.length + 1 + (showPymk ? 1 : 0);

            return CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                CupertinoSliverRefreshControl(
                  refreshTriggerPullDistance: 70.0,
                  refreshIndicatorExtent: 44.0,
                  onRefresh: () async {
                    ref.read(postLocalStatesProvider.notifier).clearAll();
                    ref.invalidate(feedPostsProvider);
                    if (currentUserId != null) {
                      ref.invalidate(pymkProvider(currentUserId));
                    }
                  },
                  builder: (ctx, mode, pulledExtent, triggerDistance, indicatorExtent) {
                    return _FeedRefreshHeader(
                      mode: mode,
                      pulledExtent: pulledExtent,
                      triggerDistance: triggerDistance,
                    );
                  },
                ),
                SliverList.builder(
                  itemCount: totalItemCount,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildCreatePostHeaderBar(context, ref);
                    }

                    if (showPymk && index == pymkPosition) {
                      return PeopleYouMayKnowCarousel(currentUserId: currentUserId);
                    }

                    final postIndex = (showPymk && index > pymkPosition) ? index - 2 : index - 1;
                    if (postIndex < 0 || postIndex >= posts.length) {
                      return const SizedBox.shrink();
                    }

                    return PostCard(
                      post: posts[postIndex],
                      currentUserId: currentUserId ?? '',
                    );
                  },
                ),
              ],
            );
          },
          loading: () => _buildShimmer(context),
          error: (e, _) => AppErrorWidget(
            message: e.toString(),
            onRetry: () {
              ref.read(postLocalStatesProvider.notifier).clearAll();
              ref.invalidate(feedPostsProvider);
            },
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
  Widget _buildCreatePostHeaderBar(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final profileAsync = ref.watch(profileProvider(currentUserId ?? ''));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          profileAsync.when(
            data: (profile) => AppAvatar(
              imageUrl: profile.avatarUrl,
              name: profile.displayName,
              radius: 20,
            ),
            loading: () => const CircleAvatar(radius: 20, backgroundColor: Colors.transparent),
            error: (_, __) => const CircleAvatar(radius: 20, backgroundColor: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => context.push('/create'),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  AppTranslations.tr(ref, 'whats_on_your_mind'),
                  style: TextStyle(
                    color: theme.hintColor,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(CupertinoIcons.photo_on_rectangle, color: Colors.green, size: 22),
            onPressed: () => context.push('/create'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Pull-to-Refresh Header
// ─────────────────────────────────────────────────────────────────────────────
class _FeedRefreshHeader extends StatefulWidget {
  final RefreshIndicatorMode mode;
  final double pulledExtent;
  final double triggerDistance;

  const _FeedRefreshHeader({
    required this.mode,
    required this.pulledExtent,
    required this.triggerDistance,
  });

  @override
  State<_FeedRefreshHeader> createState() => _FeedRefreshHeaderState();
}

class _FeedRefreshHeaderState extends State<_FeedRefreshHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didUpdateWidget(_FeedRefreshHeader old) {
    super.didUpdateWidget(old);
    if (widget.mode == RefreshIndicatorMode.refresh) {
      if (!_spinController.isAnimating) _spinController.repeat();
    } else {
      _spinController.stop();
      _spinController.reset();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (widget.pulledExtent / widget.triggerDistance).clamp(0.0, 1.0);
    final isRefreshing = widget.mode == RefreshIndicatorMode.refresh;
    final isArmed = widget.mode == RefreshIndicatorMode.armed ||
        widget.pulledExtent >= widget.triggerDistance;

    return Container(
      height: widget.pulledExtent,
      alignment: Alignment.center,
      child: AnimatedOpacity(
        opacity: progress.clamp(0.0, 1.0),
        duration: const Duration(milliseconds: 100),
        child: AnimatedBuilder(
          animation: _spinController,
          builder: (context, child) {
            final angle = isRefreshing
                ? _spinController.value * 2 * pi
                : progress * pi * 2;
            return Transform.rotate(
              angle: angle,
              child: child,
            );
          },
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isArmed || isRefreshing
                    ? [AppColors.primary, const Color(0xFF7C3AED)]
                    : [AppColors.primary.withValues(alpha: 0.6), AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: isRefreshing ? 0.35 : 0.15),
                  blurRadius: isRefreshing ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
