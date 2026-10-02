import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/date_extension.dart';
import '../../../story/domain/story_model.dart';
import '../../../story/presentation/widgets/story_viewer_modal.dart';
import '../../../story/providers/story_provider.dart';

class ProfileStoriesGrid extends ConsumerWidget {
  final String userId;

  const ProfileStoriesGrid({super.key, required this.userId});

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
        if (stories.isEmpty) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: 260,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.clock,
                          size: 38,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Chưa có tin nào được lưu trữ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tất cả các tin người dùng đã đăng từ trước đến nay sẽ tự động được lưu trữ và hiển thị tại đây.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(2),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
              childAspectRatio: 9 / 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final story = stories[index];
                return _buildStoryCard(context, story, stories, index);
              },
              childCount: stories.length,
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: Center(child: CupertinoActivityIndicator()),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text(
              'Lỗi tải kho lưu trữ tin: $e',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoryCard(BuildContext context, StoryModel story,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          color: bgColor,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media or Solid Background
              if (hasMedia)
                Image.network(
                  story.mediaUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: bgColor),
                )
              else if (story.caption != null && story.caption!.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      story.caption!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 4,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              // Gradient Overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.65),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // Top Status Badge (Active 24h vs Archived)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isStillActive
                        ? const Color(0xFF10B981).withValues(alpha: 0.9)
                        : Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isStillActive
                            ? CupertinoIcons.bolt_fill
                            : CupertinoIcons.clock,
                        color: Colors.white,
                        size: 9,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isStillActive ? 'Đang hiện' : 'Đã lưu',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Music Icon badge if story has music track
              if (story.musicTrack != null)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.black54,
                    child: Icon(
                      CupertinoIcons.music_note_2,
                      color: Color(0xFF38BDF8),
                      size: 10,
                    ),
                  ),
                ),

              // Bottom Date Label
              Positioned(
                bottom: 6,
                left: 6,
                right: 6,
                child: Text(
                  story.createdAt.timeAgo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(blurRadius: 4, color: Colors.black),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
