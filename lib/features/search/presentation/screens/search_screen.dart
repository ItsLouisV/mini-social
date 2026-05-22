import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../social/providers/follow_provider.dart';
import '../../providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider(_query));

    return Scaffold(
      body: Column(
        children: [
          CupertinoNavigationBar(
            transitionBetweenRoutes: false,
            backgroundColor:
                Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => context.pop(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.chevron_back,
                      color: Theme.of(context).colorScheme.primary, size: 18),
                  const SizedBox(width: 2),
                  Text('Huỷ',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 16)),
                ],
              ),
            ),
            middle: CupertinoSearchTextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              placeholder: 'Tìm kiếm người dùng...',
              style: AppTextStyles.bodyMedium,
            ),
          ),
          Expanded(
            child: _query.isEmpty
                ? _buildEmpty()
                : resultsAsync.when(
                    data: (users) {
                      if (users.isEmpty) {
                        return Center(
                          child: Text(
                            'Không tìm thấy "$_query"',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: Theme.of(context).hintColor),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final isFollowingAsync =
                              ref.watch(isFollowingProvider(user.id));

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: AppAvatar(
                              imageUrl: user.avatarUrl,
                              name: user.displayName,
                              radius: 22,
                            ),
                            title: Text(user.displayName,
                                style: AppTextStyles.titleSmall),
                            subtitle: Text('@${user.username}',
                                style: AppTextStyles.caption),
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 6),
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
                    loading: () =>
                        const Center(child: CupertinoActivityIndicator()),
                    error: (e, _) =>
                        Center(child: Text(e.toString())),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.search,
              size: 64, color: Theme.of(context).hintColor),
          const SizedBox(height: 16),
          Text('Tìm kiếm người dùng',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: Theme.of(context).hintColor)),
          const SizedBox(height: 8),
          const Text('Tìm theo tên hoặc username',
              style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
