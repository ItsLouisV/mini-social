import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/search_repository.dart';
import '../../profile/domain/profile_model.dart';
import '../../../shared/providers/supabase_provider.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(supabaseClientProvider));
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider =
    FutureProvider.family<List<ProfileModel>, String>((ref, query) async {
  if (query.length < 2) return [];
  return ref.watch(searchRepositoryProvider).searchUsers(query);
});
