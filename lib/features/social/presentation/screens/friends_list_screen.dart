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

class FriendsListScreen extends ConsumerWidget {
  final String userId;
  final int initialIndex;

  const FriendsListScreen({
    super.key,
    required this.userId,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          leading: CupertinoButton(
            padding: const EdgeInsets.only(left: 8),
            onPressed: () => context.pop(),
            child: const Icon(CupertinoIcons.chevron_back, size: 22),
          ),
          title: const Text(
            'Bạn bè',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Bạn bè'),
              Tab(text: 'Chờ xác nhận'),
              Tab(text: 'Đã gửi'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FriendsListTab(
              provider: friendsListProvider(userId),
              emptyMessage: 'Chưa có người bạn nào',
              tabType: _FriendTabType.friends,
            ),
            _FriendsListTab(
              provider: pendingReceivedProvider(userId),
              emptyMessage: 'Không có lời mời kết bạn nào',
              tabType: _FriendTabType.pendingReceived,
            ),
            _FriendsListTab(
              provider: pendingSentProvider(userId),
              emptyMessage: 'Không có lời mời nào đã gửi',
              tabType: _FriendTabType.pendingSent,
            ),
          ],
        ),
      ),
    );
  }
}

enum _FriendTabType { friends, pendingReceived, pendingSent }

class _FriendsListTab extends ConsumerWidget {
  final ProviderListenable<AsyncValue<List<ProfileModel>>> provider;
  final String emptyMessage;
  final _FriendTabType tabType;

  const _FriendsListTab({
    required this.provider,
    required this.emptyMessage,
    required this.tabType,
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

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: AppAvatar(
                imageUrl: user.avatarUrl,
                name: user.displayName,
                radius: 22,
              ),
              title: Text(user.displayName, style: AppTextStyles.titleSmall),
              subtitle: Text('@${user.username}', style: AppTextStyles.caption),
              trailing: _buildActionButtons(context, ref, user.id),
              onTap: () => context.push('/profile/${user.id}'),
            );
          },
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, String targetUserId) {
    final theme = Theme.of(context);
    
    switch (tabType) {
      case _FriendTabType.friends:
        return OutlinedButton(
          onPressed: () => _showUnfriendOptions(context, ref, targetUserId),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
            backgroundColor: Colors.green.withOpacity(0.1),
            side: BorderSide(color: Colors.green.withOpacity(0.2)),
          ),
          child: const Text(
            'Bạn bè',
            style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
          ),
        );
      case _FriendTabType.pendingReceived:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                ref.read(friendStatusProvider(targetUserId).notifier).acceptRequest();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: Size.zero,
                elevation: 0,
              ),
              child: const Text('Chấp nhận', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: () {
                ref.read(friendStatusProvider(targetUserId).notifier).cancelOrUnfriend();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: Size.zero,
                side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
              ),
              child: Text(
                'Từ chối',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.error),
              ),
            ),
          ],
        );
      case _FriendTabType.pendingSent:
        return OutlinedButton(
          onPressed: () {
            ref.read(friendStatusProvider(targetUserId).notifier).cancelOrUnfriend();
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
            side: BorderSide(color: theme.dividerColor),
          ),
          child: Text(
            'Thu hồi',
            style: TextStyle(fontSize: 12, color: theme.hintColor),
          ),
        );
    }
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
}
