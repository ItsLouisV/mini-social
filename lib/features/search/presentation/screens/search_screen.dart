import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/widgets/app_avatar.dart';
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
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Tìm kiếm người dùng...',
            hintStyle:
                AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).hintColor),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
          style: AppTextStyles.bodyLarge,
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(CupertinoIcons.xmark_circle_fill),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: _query.isEmpty
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
                      trailing: isFollowingAsync.when(
                        data: (isFollowing) => OutlinedButton(
                          onPressed: () {
                            if (isFollowing) {
                              ref
                                  .read(followActionsProvider.notifier)
                                  .unfollow(user.id);
                            } else {
                              ref
                                  .read(followActionsProvider.notifier)
                                  .follow(user.id);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            minimumSize: Size.zero,
                            side: BorderSide(
                              color: isFollowing
                                  ? Theme.of(context).dividerColor
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          child: Text(
                            isFollowing ? 'Đang theo dõi' : 'Theo dõi',
                            style: TextStyle(
                              fontSize: 12,
                              color: isFollowing
                                  ? Theme.of(context).hintColor
                                  : Theme.of(context).colorScheme.primary,
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
