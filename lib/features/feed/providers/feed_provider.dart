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

// Comments provider
final commentsProvider =
    StreamProvider.family<List<CommentModel>, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).watchComments(postId);
});

// Like action notifier (optimistic update)
class LikeNotifier extends StateNotifier<AsyncValue<bool?>> {
  final PostRepository _repo;
  final String _postId;

  LikeNotifier(this._repo, this._postId)
      : super(const AsyncData(null));

  Future<void> toggle(bool currentIsLiked) async {
    // Optimistic update
    state = AsyncData(!currentIsLiked);

    try {
      if (currentIsLiked) {
        await _repo.unlikePost(_postId);
      } else {
        await _repo.likePost(_postId);
      }
    } catch (_) {
      // Rollback
      state = AsyncData(currentIsLiked);
    }
  }
}

final likeNotifierProvider =
    StateNotifierProvider.family<LikeNotifier, AsyncValue<bool?>, String>(
        (ref, postId) {
  final repo = ref.watch(postRepositoryProvider);
  return LikeNotifier(repo, postId);
});

// ── Local Post Visibility & Report States ──

enum PostLocalStatus {
  none,
  hidden,
  snoozed,
  reported,
  trashed,
  dismissed,
}

class PostLocalStatesNotifier extends StateNotifier<Map<String, PostLocalStatus>> {
  PostLocalStatesNotifier() : super({});

  void hidePost(String postId) {
    state = {...state, postId: PostLocalStatus.hidden};
  }

  void snoozePost(String postId) {
    state = {...state, postId: PostLocalStatus.snoozed};
  }

  void reportPost(String postId) {
    state = {...state, postId: PostLocalStatus.reported};
  }

  void trashPost(String postId) {
    state = {...state, postId: PostLocalStatus.trashed};
  }

  void dismissPost(String postId) {
    state = {...state, postId: PostLocalStatus.dismissed};
  }

  void undo(String postId) {
    final newState = Map<String, PostLocalStatus>.from(state);
    newState.remove(postId);
    state = newState;
  }

  void clearAll() {
    state = {};
  }
}

final postLocalStatesProvider =
    StateNotifierProvider<PostLocalStatesNotifier, Map<String, PostLocalStatus>>((ref) {
  return PostLocalStatesNotifier();
});

/// Stream/Future provider lấy danh sách bài viết trong thùng rác
final trashedPostsProvider = FutureProvider<List<PostModel>>((ref) async {
  return ref.watch(postRepositoryProvider).getTrashedPosts();
});
