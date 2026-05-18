import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../search/providers/search_provider.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../core/services/supabase_service.dart';
import '../../providers/chat_provider.dart';

class NewMessageModal extends ConsumerStatefulWidget {
  const NewMessageModal({super.key});

  @override
  ConsumerState<NewMessageModal> createState() => _NewMessageModalState();
}

class _NewMessageModalState extends ConsumerState<NewMessageModal> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(searchQueryProvider.notifier).state = value;
  }

  Future<void> _startConversation(String userId) async {
    try {
      final repository = ref.read(chatRepositoryProvider);
      final conversation = await repository.getOrCreateConversation(userId);
      if (mounted) {
        context.pop(conversation.id); // Return ID to parent
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể bắt đầu trò chuyện: $e')),
        );
        debugPrint(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = ref.watch(searchQueryProvider);
    final searchResults = ref.watch(searchResultsProvider(query));

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: theme.dividerColor, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40), // Balance
                    Text(
                      'Tin nhắn mới',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 20),
                      ),
                      onPressed: () => context.pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey[900]
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm người dùng...',
                      hintStyle: TextStyle(color: theme.hintColor),
                      prefixIcon: Icon(CupertinoIcons.search, color: theme.hintColor),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),

              // Results
              Expanded(
                child: query.isEmpty
                    ? Center(
                        child: Text(
                          'Nhập tên để tìm kiếm',
                          style: TextStyle(color: theme.hintColor),
                        ),
                      )
                    : searchResults.when(
                        data: (allUsers) {
                          final currentUserId = ref.read(supabaseServiceProvider).currentUserId;
                          final users = allUsers.where((u) => u.id != currentUserId).toList();
                          if (users.isEmpty) {
                            return Center(
                              child: Text(
                                'Không tìm thấy người dùng nào',
                                style: TextStyle(color: theme.hintColor),
                              ),
                            );
                          }
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final user = users[index];
                              return ListTile(
                                leading: AppAvatar(
                                  imageUrl: user.avatarUrl,
                                  name: user.displayName,
                                  radius: 20,
                                ),
                                title: Text(
                                  user.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text('@${user.username}'),
                                onTap: () => _startConversation(user.id),
                              );
                            },
                          );
                        },
                        loading: () => const Center(
                          child: CupertinoActivityIndicator(),
                        ),
                        error: (error, _) => Center(
                          child: Text('Lỗi: $error'),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
