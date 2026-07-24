import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../social/data/recommendation_repository.dart';
import '../../../social/providers/follow_provider.dart';
import '../../providers/feed_provider.dart';

class PeopleYouMayKnowCarousel extends ConsumerStatefulWidget {
  final String currentUserId;

  const PeopleYouMayKnowCarousel({
    super.key,
    required this.currentUserId,
  });

  @override
  ConsumerState<PeopleYouMayKnowCarousel> createState() => _PeopleYouMayKnowCarouselState();
}

class _PeopleYouMayKnowCarouselState extends ConsumerState<PeopleYouMayKnowCarousel> {
  final Set<String> _sentRequests = {};
  final Set<String> _dismissedCandidates = {};
  bool _isDismissedAll = false;

  @override
  Widget build(BuildContext context) {
    if (_isDismissedAll || widget.currentUserId.isEmpty) {
      return const SizedBox.shrink();
    }

    final pymkAsync = ref.watch(pymkProvider(widget.currentUserId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return pymkAsync.when(
      data: (candidates) {
        final visibleCandidates = candidates
            .where((c) => !_dismissedCandidates.contains(c.id))
            .toList();

        if (visibleCandidates.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF242526) : Colors.white,
            border: Border.symmetric(
              horizontal: BorderSide(
                color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1877F2), Color(0xFF00C6FF)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        CupertinoIcons.person_2_fill,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Những người bạn có thể biết',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Dựa trên bạn chung & sở thích tương đồng',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        CupertinoIcons.xmark,
                        size: 18,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      onPressed: () {
                        setState(() {
                          _isDismissedAll = true;
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Carousel Horizontal List ──
              SizedBox(
                height: 265,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: visibleCandidates.length,
                  itemBuilder: (context, index) {
                    final candidate = visibleCandidates[index];
                    final isSent = _sentRequests.contains(candidate.id);

                    return Container(
                      width: 160,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF18191A) : const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF3E4042) : const Color(0xFFE4E6EB),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Avatar & Profile click
                          GestureDetector(
                            onTap: () => context.push('/profile/${candidate.id}'),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: AspectRatio(
                                aspectRatio: 1.25,
                                child: candidate.avatarUrl != null && candidate.avatarUrl!.isNotEmpty
                                    ? Image.network(
                                        candidate.avatarUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(candidate.fullName, isDark),
                                      )
                                    : _buildAvatarPlaceholder(candidate.fullName, isDark),
                              ),
                            ),
                          ),

                          // Profile Info
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  candidate.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _buildSubtext(candidate),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          // Actions
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 32,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isSent
                                          ? (isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB))
                                          : const Color(0xFF1877F2),
                                      foregroundColor: isSent
                                          ? (isDark ? Colors.grey.shade300 : Colors.black87)
                                          : Colors.white,
                                      elevation: 0,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: isSent
                                        ? null
                                        : () async {
                                            setState(() {
                                              _sentRequests.add(candidate.id);
                                            });
                                            try {
                                              await ref.read(socialRepositoryProvider).sendFriendRequest(candidate.id);
                                            } catch (e) {
                                              debugPrint('Error sending friend request: $e');
                                            }
                                          },
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isSent ? CupertinoIcons.checkmark_alt : CupertinoIcons.person_add_solid,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isSent ? 'Đã gửi' : 'Thêm bạn bè',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: double.infinity,
                                  height: 28,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _dismissedCandidates.add(candidate.id);
                                      });
                                    },
                                    child: const Text(
                                      'Gỡ',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildAvatarPlaceholder(String name, bool isDark) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }

  String _buildSubtext(PymkCandidate candidate) {
    if (candidate.mutualFriendsCount > 0) {
      return '${candidate.mutualFriendsCount} bạn chung';
    }
    if (candidate.sharedInterestsCount > 0) {
      return '${candidate.sharedInterestsCount} sở thích chung';
    }
    return 'Gợi ý cho bạn';
  }
}
