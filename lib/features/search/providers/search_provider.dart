import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/search_repository.dart';
import '../../profile/domain/profile_model.dart';
import '../../feed/domain/post_model.dart';
import '../../../shared/providers/supabase_provider.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(supabaseClientProvider));
});

/// Lưu từ khoá đang nhập
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Quản lý lịch sử tìm kiếm gần đây lưu trên SharedPreferences
class SearchHistoryNotifier extends StateNotifier<List<String>> {
  static const _historyKey = 'recent_searches_list';

  SearchHistoryNotifier() : super([]) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_historyKey) ?? [];
      state = list;
    } catch (_) {}
  }

  Future<void> addSearchTerm(String term) async {
    final clean = term.trim();
    if (clean.length < 2) return;

    final updated = List<String>.from(state);
    updated.removeWhere((item) => item.toLowerCase() == clean.toLowerCase());
    updated.insert(0, clean);
    if (updated.length > 15) {
      updated.removeLast();
    }
    state = updated;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_historyKey, updated);
    } catch (_) {}
  }

  Future<void> removeSearchTerm(String term) async {
    final updated = List<String>.from(state)..remove(term);
    state = updated;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_historyKey, updated);
    } catch (_) {}
  }

  Future<void> clearAllHistory() async {
    state = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (_) {}
  }
}

final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});

/// Tìm kiếm người dùng theo query
final searchUsersProvider =
    FutureProvider.family<List<ProfileModel>, String>((ref, query) async {
  if (query.trim().length < 2) return [];
  return ref.watch(searchRepositoryProvider).searchUsers(query);
});

/// Alias phục vụ new_message_modal.dart
final searchResultsProvider =
    FutureProvider.family<List<ProfileModel>, String>((ref, query) async {
  if (query.trim().length < 2) return [];
  return ref.watch(searchRepositoryProvider).searchUsers(query);
});

/// Tìm kiếm bài viết theo query
final searchPostsProvider =
    FutureProvider.family<List<PostModel>, String>((ref, query) async {
  if (query.trim().length < 2) return [];
  return ref.watch(searchRepositoryProvider).searchPosts(query);
});

/// Gợi ý người dùng khi ô tìm kiếm trống
final suggestedUsersProvider = FutureProvider<List<ProfileModel>>((ref) async {
  return ref.watch(searchRepositoryProvider).getSuggestedUsers(limit: 10);
});
