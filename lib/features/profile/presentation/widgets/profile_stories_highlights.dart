import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/date_extension.dart';
import '../../../story/domain/story_model.dart';
import '../../../story/presentation/widgets/create_story_modal.dart';
import '../../../story/presentation/widgets/story_viewer_modal.dart';
import '../../../story/providers/story_provider.dart';

class ProfileStoriesHighlights extends ConsumerWidget {
  final String userId;
  final bool isMine;

  const ProfileStoriesHighlights({
    super.key,
    required this.userId,
    required this.isMine,
  });

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFF1C1C1E);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(userStoriesProvider(userId));

    return storiesAsync.when(
      data: (stories) {
        if (stories.isEmpty && !isMine) {
          return const SizedBox.shrink();
        }

        final displayStories = stories.take(5).toList();

        return Container(
          height: 104,
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: (isMine ? 1 : 0) + displayStories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, idx) {
              if (isMine && idx == 0) {
                return _buildAddStoryButton(context, ref);
              }

              final storyIdx = isMine ? idx - 1 : idx;
              final story = displayStories[storyIdx];
              return _buildStoryHighlightItem(
                  context, story, stories, storyIdx);
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 104,
        child: Center(child: CupertinoActivityIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildAddStoryButton(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final res = await CreateStoryModal.show(context);
        if (res == true) {
          ref.invalidate(userStoriesProvider(userId));
          ref.invalidate(activeStoriesProvider);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 1.5,
              ),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Icon(
              CupertinoIcons.add,
              color: Theme.of(context).colorScheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 6),
          const SizedBox(
            width: 68,
            child: Text(
              'Thêm tin',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryHighlightItem(BuildContext context, StoryModel story,
      List<StoryModel> allStories, int index) {
    final bgColor = _hexToColor(story.backgroundColor);
    final hasMedia = story.mediaUrl != null && story.mediaUrl!.isNotEmpty;
    final isStillActive = !story.isExpired;

    return GestureDetector(
      onTap: () {
        StoryViewerModal.show(
          context,
          stories: allStories,
          initialStoryIndex: index,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isStillActive
                  ? const LinearGradient(
                      colors: [
                        Color(0xFFF59E0B),
                        Color(0xFFEC4899),
                        Color(0xFF8B5CF6),
                      ],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.grey.shade600,
                        Colors.grey.shade400,
                      ],
                    ),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: ClipOval(
                child: Container(
                  color: bgColor,
                  child: hasMedia
                      ? Image.network(
                          story.mediaUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: bgColor),
                        )
                      : const Center(
                          child: Icon(
                            CupertinoIcons.textformat,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 68,
            child: Text(
              story.caption != null && story.caption!.isNotEmpty
                  ? story.caption!
                  : story.createdAt.timeAgo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
