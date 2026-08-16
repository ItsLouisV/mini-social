import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../domain/story_model.dart';
import '../../providers/story_provider.dart';
import 'create_story_modal.dart';
import 'story_viewer_modal.dart';

class StoriesBar extends ConsumerWidget {
  const StoriesBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final myProfileAsync = ref.watch(profileProvider(currentUserId ?? ''));
    final storiesAsync = ref.watch(activeStoriesProvider);
    final theme = Theme.of(context);

    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          storiesAsync.when(
            data: (stories) {
              // Group stories by userId
              final Map<String, List<StoryModel>> userStoriesMap = {};
              for (final s in stories) {
                userStoriesMap.putIfAbsent(s.userId, () => []).add(s);
              }

              // Extract My Stories vs Friends Stories
              List<StoryModel>? myStories;
              final List<List<StoryModel>> friendStoryGroups = [];

              for (final entry in userStoriesMap.entries) {
                if (currentUserId != null && entry.key == currentUserId) {
                  myStories = entry.value;
                } else {
                  friendStoryGroups.add(entry.value);
                }
              }

              // Sắp xếp tin bạn bè: Tin còn thời hạn lâu nhất xếp trước, tin gần hết hạn nhất đẩy về sau cùng
              friendStoryGroups.sort((a, b) {
                final aMaxExpires = a.map((s) => s.expiresAt).reduce((x, y) => x.isAfter(y) ? x : y);
                final bMaxExpires = b.map((s) => s.expiresAt).reduce((x, y) => x.isAfter(y) ? x : y);
                return bMaxExpires.compareTo(aMaxExpires); // Descending remaining time
              });

              final hasMyStories = myStories != null && myStories.isNotEmpty;

              return Row(
                children: [
                  // 1. Thẻ Tạo tin mới (CHUYÊN DỤNG TẠO TIN)
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: GestureDetector(
                      onTap: () => CreateStoryModal.show(context),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              myProfileAsync.when(
                                data: (profile) => AppAvatar(
                                  imageUrl: profile.avatarUrl,
                                  name: profile.displayName,
                                  radius: 24,
                                ),
                                loading: () => const CircleAvatar(radius: 24, backgroundColor: Colors.grey),
                                error: (_, __) => const CircleAvatar(radius: 24, backgroundColor: Colors.grey),
                              ),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF007AFF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.plus,
                                    size: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tạo tin',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Thẻ Xem tin của bạn (CHỈ HIỆN KHI ĐÃ ĐĂNG TIN)
                  if (hasMyStories)
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: GestureDetector(
                        onTap: () => StoryViewerModal.show(context, stories: myStories!),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFE040FB),
                                    Color(0xFF7C4DFF),
                                    Color(0xFF00B0FF),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: theme.scaffoldBackgroundColor,
                                  shape: BoxShape.circle,
                                ),
                                child: myProfileAsync.when(
                                  data: (profile) => AppAvatar(
                                    imageUrl: profile.avatarUrl,
                                    name: profile.displayName,
                                    radius: 24,
                                  ),
                                  loading: () => const CircleAvatar(radius: 24, backgroundColor: Colors.grey),
                                  error: (_, __) => const CircleAvatar(radius: 24, backgroundColor: Colors.grey),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tin của bạn',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 2. Vị trí 2+: Tin của Bạn bè (Đã xếp theo thời gian hết hạn giảm dần)
                  ...friendStoryGroups.map((userStoryList) {
                    final firstStory = userStoryList.first;
                    final author = firstStory.author;

                    return Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: GestureDetector(
                        onTap: () => StoryViewerModal.show(
                          context,
                          stories: userStoryList,
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFE040FB),
                                    Color(0xFF7C4DFF),
                                    Color(0xFF00B0FF),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: theme.scaffoldBackgroundColor,
                                  shape: BoxShape.circle,
                                ),
                                child: AppAvatar(
                                  imageUrl: author?.avatarUrl,
                                  name: author?.displayName ?? 'User',
                                  radius: 24,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 62,
                              child: Text(
                                author?.displayName ?? 'Tin mới',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
