import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/post_repository.dart';
import '../domain/comment_model.dart';
import '../domain/post_model.dart';
import '../../../core/services/supabase_service.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(ref.watch(supabaseServiceProvider));
});

final feedPostsProvider = StreamProvider<List<PostModel>>((ref) {
  return ref.watch(postRepositoryProvider).watchPosts();
});

// Single post
final postDetailProvider =
    StreamProvider.family<PostModel, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).watchPost(postId);
});

// Is liked provider
final isLikedProvider =
    FutureProvider.family<bool, String>((ref, postId) async {
  return ref.watch(postRepositoryProvider).isLiked(postId);
});

// Comments provider
final commentsProvider =
    StreamProvider.family<List<CommentModel>, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).watchComments(postId);
});

// Like action notifier (optimistic update)
class LikeNotifier extends StateNotifier<AsyncValue<bool>> {
  final PostRepository _repo;
  final String _postId;

  LikeNotifier(this._repo, this._postId, bool initialValue)
      : super(AsyncData(initialValue));

  Future<void> toggle() async {
    final current = state.value ?? false;
    // Optimistic update
    state = AsyncData(!current);

    try {
      if (current) {
        await _repo.unlikePost(_postId);
      } else {
        await _repo.likePost(_postId);
      }
    } catch (_) {
      // Rollback
      state = AsyncData(current);
    }
  }
}

final likeNotifierProvider =
    StateNotifierProvider.family<LikeNotifier, AsyncValue<bool>, String>(
        (ref, postId) {
  final repo = ref.watch(postRepositoryProvider);
  final isLiked = ref.watch(isLikedProvider(postId));
  return LikeNotifier(repo, postId, isLiked.value ?? false);
});
