import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../profile/domain/profile_model.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../../social/providers/follow_provider.dart';

class QrProfileBottomSheet extends ConsumerWidget {
  final String targetUserId;

  const QrProfileBottomSheet({
    super.key,
    required this.targetUserId,
  });

  static Future<void> show(BuildContext context, String targetUserId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QrProfileBottomSheet(targetUserId: targetUserId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final profileAsync = ref.watch(profileProvider(targetUserId));
    final friendStatusAsync = ref.watch(friendStatusProvider(targetUserId));
    final friendStatus = friendStatusAsync.value ?? FriendStatus.none;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle pill
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: profileAsync.when(
              data: (profile) => _buildProfileContent(context, ref, profile, friendStatus),
              loading: () => Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              ),
              error: (e, _) => AppErrorWidget(
                message: e.toString(),
                onRetry: () => ref.invalidate(profileProvider(targetUserId)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    WidgetRef ref,
    ProfileModel profile,
    FriendStatus friendStatus,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          // Glowing Avatar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: AppAvatar(
              imageUrl: profile.avatarUrl,
              name: profile.displayName,
              radius: 46,
            ),
          ),
          const SizedBox(height: 14),

          // Full Name & Username
          Text(
            profile.displayName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          if (profile.username.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '@${profile.username}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          // Bio
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              profile.bio!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 24),

          // Quick Stats Container
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(context, 'Bài viết', profile.postsCount),
                VerticalDivider(color: colorScheme.outlineVariant, thickness: 1, width: 1),
                _buildStatItem(context, 'Người theo dõi', profile.followersCount),
                VerticalDivider(color: colorScheme.outlineVariant, thickness: 1, width: 1),
                _buildStatItem(context, 'Đang theo dõi', profile.followingCount),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Friend Action Button
          _buildActionButton(context, ref, profile, friendStatus),

          const SizedBox(height: 12),

          // Full Profile Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                context.pop();
                context.push('/profile/${profile.id}');
              },
              icon: Icon(CupertinoIcons.person_crop_circle, color: colorScheme.primary, size: 20),
              label: Text(
                'Xem trang cá nhân đầy đủ',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, int value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Text(
          '$value',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    WidgetRef ref,
    ProfileModel profile,
    FriendStatus friendStatus,
  ) {
    String label = 'Kết bạn';
    Color bgColor = const Color(0xFF38BDF8);
    Color textColor = Colors.white;
    IconData iconData = CupertinoIcons.person_badge_plus;
    VoidCallback? onTap;

    switch (friendStatus) {
      case FriendStatus.none:
        label = 'Kết bạn';
        bgColor = const Color(0xFF38BDF8);
        iconData = CupertinoIcons.person_badge_plus;
        onTap = () => ref.read(friendStatusProvider(profile.id).notifier).sendRequest();
        break;
      case FriendStatus.pendingSent:
        label = 'Đã gửi lời mời';
        bgColor = Theme.of(context).colorScheme.surfaceContainerHighest;
        textColor = Theme.of(context).colorScheme.onSurfaceVariant;
        iconData = CupertinoIcons.clock_fill;
        onTap = () => ref.read(friendStatusProvider(profile.id).notifier).cancelOrUnfriend();
        break;
      case FriendStatus.pendingReceived:
        label = 'Chấp nhận lời mời';
        bgColor = Colors.green;
        iconData = CupertinoIcons.checkmark_alt;
        onTap = () => ref.read(friendStatusProvider(profile.id).notifier).acceptRequest();
        break;
      case FriendStatus.accepted:
        label = 'Bạn bè';
        bgColor = Colors.green.withValues(alpha: 0.18);
        textColor = Colors.green;
        iconData = CupertinoIcons.person_2_fill;
        break;
    }

    if (friendStatus == FriendStatus.accepted) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: null,
                icon: Icon(iconData, color: textColor, size: 20),
                label: Text(
                  label,
                  style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: bgColor,
                  disabledBackgroundColor: bgColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.pop();
                  context.push('/chat/${profile.id}');
                },
                icon: const Icon(CupertinoIcons.chat_bubble_2_fill, color: Colors.white, size: 20),
                label: const Text(
                  'Nhắn tin',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(iconData, color: textColor, size: 20),
        label: Text(
          label,
          style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: bgColor.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
