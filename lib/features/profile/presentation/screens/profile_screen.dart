import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../social/providers/follow_provider.dart';
import '../../../chat/presentation/widgets/full_screen_image_viewer.dart';
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
    final friendStatusAsync = ref.watch(friendStatusProvider(profile.id));
    final isFriend = friendStatusAsync.valueOrNull == FriendStatus.accepted;
    final isLocked = profile.isPrivateProfile && !isMine && !isFriend;

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
          if (isLocked)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.lock_fill, size: 48, color: Theme.of(context).hintColor),
                      const SizedBox(height: 16),
                      const Text(
                        'Tài khoản này là riêng tư',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hãy kết bạn với ${profile.displayName} để xem hình ảnh và bài viết.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
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
            GestureDetector(
              onTap: profile.coverUrl != null && profile.coverUrl!.isNotEmpty
                  ? () => FullScreenImageViewer.open(context, profile.coverUrl!)
                  : null,
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: profile.coverUrl != null && profile.coverUrl!.isNotEmpty
                    ? Hero(
                        tag: 'cover_${profile.id}',
                        child: CachedNetworkImage(
                          imageUrl: profile.coverUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: theme.colorScheme.surfaceVariant),
                          errorWidget: (_, __, ___) => Container(color: theme.colorScheme.surfaceVariant),
                        ),
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
                      if (isMine)
                        OutlinedButton(
                          onPressed: () => context.push('/profile/edit'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text('Chỉnh sửa hồ sơ', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  if (profile.bio?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    _ClickableBioText(
                      text: profile.bio!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  if (profile.interests.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: profile.interests.map((interest) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            interest,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  
                  // Inline Stats
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/profile/${profile.id}/follows?tab=followers'),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${profile.followersCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(width: 4),
                            Text('Người theo dõi', style: TextStyle(color: theme.hintColor, fontSize: 15)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/profile/${profile.id}/follows?tab=following'),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${profile.followingCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(width: 4),
                            Text('Đang theo dõi', style: TextStyle(color: theme.hintColor, fontSize: 15)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!isMine) ...[
                    const SizedBox(height: 18),
                    Builder(
                      builder: (context) {
                        final isBlocked = ref.watch(isBlockedProvider(profile.id));
                        if (isBlocked) {
                          return Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    try {
                                      await ref.read(profileRepositoryProvider).unblockUser(profile.id);
                                      ref.invalidate(blockedUsersProvider);
                                      ref.invalidate(profileProvider(profile.id));
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Đã bỏ chặn ${profile.displayName}'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Lỗi: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: const Text('Bỏ chặn', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: _buildFriendButton(context, ref, profile)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildFollowButton(context, ref, profile)),
                          ],
                        );
                      }
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        
        // Avatar (Overlapping cover)
        Positioned(
          top: 200 - 46, // Cover height minus avatar radius
          left: 16,
          child: GestureDetector(
            onTap: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                ? () => FullScreenImageViewer.open(context, profile.avatarUrl!)
                : null,
            child: Hero(
              tag: 'avatar_${profile.id}',
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

        // Floating Profile Options/Actions Button
        if (!isMine)
          Positioned(
            top: topPadding > 0 ? topPadding + 8 : 16,
            right: 8,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.ellipsis_vertical, size: 20, color: Colors.white),
              ),
              onPressed: () => _showProfileActions(context, ref, profile),
            ),
          ),
      ],
    );
  }

  void _showProfileActions(BuildContext context, WidgetRef ref, ProfileModel profile) {
    final isBlocked = ref.read(isBlockedProvider(profile.id));
    
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Tùy chọn cho ${profile.displayName}'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: !isBlocked,
            onPressed: () async {
              ctx.pop();
              try {
                if (isBlocked) {
                  await ref.read(profileRepositoryProvider).unblockUser(profile.id);
                  ref.invalidate(blockedUsersProvider);
                  ref.invalidate(profileProvider(profile.id));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã bỏ chặn ${profile.displayName}'), backgroundColor: Colors.green),
                    );
                  }
                } else {
                  await ref.read(profileRepositoryProvider).blockUser(profile.id);
                  ref.invalidate(blockedUsersProvider);
                  ref.invalidate(profileProvider(profile.id));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã chặn ${profile.displayName}')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(isBlocked ? 'Bỏ chặn người dùng này' : 'Chặn người dùng này'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              ctx.pop();
              try {
                await ref.read(profileRepositoryProvider).muteUser(profile.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã ẩn bài viết của ${profile.displayName}')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi ẩn bài: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Ẩn bài viết của người này'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => ctx.pop(),
          child: const Text('Hủy'),
        ),
      ),
    );
  }

  Widget _buildFollowButton(
      BuildContext context, WidgetRef ref, ProfileModel profile) {
    final isFollowingAsync = ref.watch(isFollowingProvider(profile.id));
    return isFollowingAsync.when(
      data: (isFollowing) => ElevatedButton(
        onPressed: () {
          ref.read(isFollowingProvider(profile.id).notifier).toggleFollow();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isFollowing ? Theme.of(context).dividerColor.withValues(alpha: 0.1) : Theme.of(context).colorScheme.onSurface,
          foregroundColor: isFollowing ? Theme.of(context).textTheme.bodyLarge?.color : Theme.of(context).colorScheme.surface,
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

  Widget _buildFriendButton(
      BuildContext context, WidgetRef ref, ProfileModel profile) {
    final friendStatusAsync = ref.watch(friendStatusProvider(profile.id));
    return friendStatusAsync.when(
      data: (status) {
        String label = 'Kết bạn';
        Color? bgColor;
        Color? textColor;
        BorderSide? borderSide;
        VoidCallback? onTap;

        switch (status) {
          case FriendStatus.none:
            label = 'Kết bạn';
            bgColor = Colors.blue;
            textColor = Colors.white;
            onTap = () => ref.read(friendStatusProvider(profile.id).notifier).sendRequest();
            break;
          case FriendStatus.pendingSent:
            label = 'Đã gửi lời mời';
            bgColor = Theme.of(context).dividerColor.withOpacity(0.1);
            textColor = Theme.of(context).textTheme.bodyLarge?.color;
            onTap = () => ref.read(friendStatusProvider(profile.id).notifier).cancelOrUnfriend();
            break;
          case FriendStatus.pendingReceived:
            label = 'Chấp nhận';
            bgColor = Colors.green;
            textColor = Colors.white;
            onTap = () => ref.read(friendStatusProvider(profile.id).notifier).acceptRequest();
            break;
          case FriendStatus.accepted:
            label = 'Bạn bè';
            bgColor = Colors.green.withOpacity(0.1);
            textColor = Colors.green;
            borderSide = BorderSide(color: Colors.green.withOpacity(0.2), width: 1);
            onTap = () => _showUnfriendOptions(context, ref, profile.id);
            break;
        }

        return ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: bgColor,
            foregroundColor: textColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            side: borderSide,
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
      loading: () => const SizedBox(width: 100, child: Center(child: CupertinoActivityIndicator())),
      error: (_, __) => const SizedBox(),
    );
  }

  void _showUnfriendOptions(BuildContext context, WidgetRef ref, String targetUserId) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              ctx.pop();
              ref.read(friendStatusProvider(targetUserId).notifier).cancelOrUnfriend();
            },
            child: const Text('Hủy kết bạn'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => ctx.pop(),
          child: const Text('Hủy'),
        ),
      ),
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

class _ClickableBioText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _ClickableBioText({
    required this.text,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkStyle = TextStyle(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    final regex = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );

    final matches = regex.allMatches(text);
    if (matches.isEmpty) {
      return Text(text, style: style);
    }

    final List<InlineSpan> spans = [];
    int start = 0;

    for (final match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: style,
        ));
      }

      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.tryParse(url);
            if (uri != null) {
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {}
            }
          },
      ));

      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: style,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
