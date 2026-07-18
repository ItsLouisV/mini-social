import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../social/providers/follow_provider.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../../providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late TabController _tabController;
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final trimmed = value.trim();
      setState(() {
        _query = trimmed;
      });
      ref.read(searchQueryProvider.notifier).state = trimmed;
    });
  }

  void _performSearch(String value) {
    final trimmed = value.trim();
    if (trimmed.length >= 2) {
      ref.read(searchHistoryProvider.notifier).addSearchTerm(trimmed);
    }
  }

  void _selectSearchTerm(String term) {
    _controller.text = term;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: term.length),
    );
    setState(() {
      _query = term;
    });
    ref.read(searchQueryProvider.notifier).state = term;
    _performSearch(term);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = ref.watch(currentUserIdProvider) ?? '';
    final hasQuery = _query.length >= 2;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_back, size: 22),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: CupertinoSearchTextField(
            controller: _controller,
            autofocus: true,
            placeholder: 'Tìm kiếm người dùng, bài viết...',
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 14,
            ),
            onChanged: _onSearchChanged,
            onSubmitted: _performSearch,
            onSuffixTap: () {
              _controller.clear();
              setState(() {
                _query = '';
              });
              ref.read(searchQueryProvider.notifier).state = '';
            },
          ),
        ),
        bottom: hasQuery
            ? TabBar(
                controller: _tabController,
                indicatorColor: theme.colorScheme.primary,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.hintColor,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'Tất cả'),
                  Tab(text: 'Mọi người'),
                  Tab(text: 'Bài viết'),
                ],
              )
            : null,
      ),
      body: hasQuery
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildAllTab(currentUserId),
                _buildPeopleTab(currentUserId),
                _buildPostsTab(currentUserId),
              ],
            )
          : _buildEmptyQueryView(context, currentUserId),
    );
  }

  // ── 1. View Khi Chưa Nhập Từ Khoá (Lịch Sử + Gợi Ý) ──
  Widget _buildEmptyQueryView(BuildContext context, String currentUserId) {
    final theme = Theme.of(context);
    final history = ref.watch(searchHistoryProvider);
    final suggestedAsync = ref.watch(suggestedUsersProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lịch sử tìm kiếm gần đây
          if (history.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tìm kiếm gần đây',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(searchHistoryProvider.notifier).clearAllHistory();
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Xóa tất cả',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final term = history[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    CupertinoIcons.clock,
                    size: 18,
                    color: theme.hintColor,
                  ),
                  title: Text(
                    term,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      CupertinoIcons.xmark,
                      size: 14,
                      color: theme.hintColor,
                    ),
                    onPressed: () {
                      ref
                          .read(searchHistoryProvider.notifier)
                          .removeSearchTerm(term);
                    },
                  ),
                  onTap: () => _selectSearchTerm(term),
                );
              },
            ),
            const Divider(height: 24),
          ],

          // Gợi ý người dùng
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Gợi ý cho bạn',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          suggestedAsync.when(
            data: (suggestedUsers) {
              if (suggestedUsers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Chưa có gợi ý nào.',
                    style: TextStyle(color: theme.hintColor, fontSize: 13),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: suggestedUsers.length,
                itemBuilder: (context, index) {
                  final user = suggestedUsers[index];
                  return _buildUserTile(user, currentUserId);
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Lỗi tải gợi ý: $e', style: TextStyle(color: theme.colorScheme.error)),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Tab Tất Cả (All) ──
  Widget _buildAllTab(String currentUserId) {
    final theme = Theme.of(context);
    final usersAsync = ref.watch(searchUsersProvider(_query));
    final postsAsync = ref.watch(searchPostsProvider(_query));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phần người dùng (Mọi người)
          usersAsync.when(
            data: (users) {
              if (users.isEmpty) return const SizedBox.shrink();
              final displayUsers = users.take(3).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mọi người',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (users.length > 3)
                          TextButton(
                            onPressed: () {
                              _tabController.animateTo(1);
                            },
                            child: const Text('Xem tất cả', style: TextStyle(fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
                  ...displayUsers.map((user) => _buildUserTile(user, currentUserId)),
                  const Divider(height: 16),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Phần bài viết
          postsAsync.when(
            data: (posts) {
              if (posts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      'Không tìm thấy bài viết nào phù hợp với "$_query"',
                      style: TextStyle(color: theme.hintColor, fontSize: 13),
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Bài viết',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return PostCard(
                        post: post,
                        currentUserId: currentUserId,
                      );
                    },
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text('Lỗi tải bài viết: $e', style: TextStyle(color: theme.colorScheme.error)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Tab Mọi Người (People) ──
  Widget _buildPeopleTab(String currentUserId) {
    final theme = Theme.of(context);
    final usersAsync = ref.watch(searchUsersProvider(_query));

    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Text(
              'Không tìm thấy người dùng nào phù hợp với "$_query"',
              style: TextStyle(color: theme.hintColor, fontSize: 13),
            ),
          );
        }
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _buildUserTile(user, currentUserId);
          },
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (e, _) => Center(
        child: Text('Lỗi tải người dùng: $e', style: TextStyle(color: theme.colorScheme.error)),
      ),
    );
  }

  // ── 4. Tab Bài Viết (Posts) ──
  Widget _buildPostsTab(String currentUserId) {
    final theme = Theme.of(context);
    final postsAsync = ref.watch(searchPostsProvider(_query));

    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Text(
              'Không tìm thấy bài viết nào phù hợp với "$_query"',
              style: TextStyle(color: theme.hintColor, fontSize: 13),
            ),
          );
        }
        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return PostCard(
              post: post,
              currentUserId: currentUserId,
            );
          },
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (e, _) => Center(
        child: Text('Lỗi tải bài viết: $e', style: TextStyle(color: theme.colorScheme.error)),
      ),
    );
  }

  // ── Component User Tile với nút Follow ──
  Widget _buildUserTile(dynamic user, String currentUserId) {
    final theme = Theme.of(context);
    final isFollowingAsync = ref.watch(isFollowingProvider(user.id));
    final isSelf = user.id == currentUserId;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: AppAvatar(
        imageUrl: user.avatarUrl,
        name: user.displayName,
        radius: 22,
        onTap: () => context.push('/profile/${user.id}'),
      ),
      title: Text(
        user.displayName,
        style: AppTextStyles.titleSmall.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '@${user.username}',
        style: AppTextStyles.caption.copyWith(
          color: theme.hintColor,
        ),
      ),
      trailing: isSelf
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Tôi',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            )
          : isFollowingAsync.when(
              data: (isFollowing) => OutlinedButton(
                onPressed: () {
                  ref.read(isFollowingProvider(user.id).notifier).toggleFollow();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  side: BorderSide(
                    color: isFollowing
                        ? theme.dividerColor
                        : theme.colorScheme.primary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  isFollowing ? 'Đang theo dõi' : 'Theo dõi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isFollowing
                        ? theme.hintColor
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
              loading: () => const SizedBox(
                width: 60,
                child: CupertinoActivityIndicator(),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
      onTap: () => context.push('/profile/${user.id}'),
    );
  }
}
