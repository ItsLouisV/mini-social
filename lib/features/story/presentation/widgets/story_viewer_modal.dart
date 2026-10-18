import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/date_extension.dart';
import '../../../../core/services/audio_player/app_audio_player.dart';
import '../../../../core/services/toast_service.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/story_model.dart';
import '../../providers/story_provider.dart';
import 'story_reaction_burst_overlay.dart';

class StoryViewerModal extends ConsumerStatefulWidget {
  final List<List<StoryModel>> allGroups;
  final int initialUserIndex;
  final int initialStoryIndex;

  const StoryViewerModal({
    super.key,
    required this.allGroups,
    this.initialUserIndex = 0,
    this.initialStoryIndex = 0,
  });

  static void show(
    BuildContext context, {
    List<StoryModel>? stories,
    List<List<StoryModel>>? allGroups,
    int initialUserIndex = 0,
    int initialStoryIndex = 0,
  }) {
    final groups = allGroups ??
        (stories != null && stories.isNotEmpty ? [stories] : []);
    if (groups.isEmpty) return;

    showGeneralDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'StoryViewer',
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => StoryViewerModal(
        allGroups: groups,
        initialUserIndex: initialUserIndex,
        initialStoryIndex: initialStoryIndex,
      ),
    );
  }

  @override
  ConsumerState<StoryViewerModal> createState() => _StoryViewerModalState();
}

class _StoryViewerModalState extends ConsumerState<StoryViewerModal> {
  late PageController _pageController;
  late int _userIndex;
  late int _storyIndex;
  Timer? _timer;
  double _progress = 0.0;
  int _currentTick = 0;
  static const int _totalTicks = 250; // 25 seconds total (250 * 100ms)
  bool _isHolding = false;
  late final AppAudioPlayer _audioPlayer;
  final GlobalKey<StoryReactionBurstOverlayState> _reactionOverlayKey =
      GlobalKey<StoryReactionBurstOverlayState>();

  @override
  void initState() {
    super.initState();
    _audioPlayer = createAudioPlayer();
    _userIndex = widget.initialUserIndex.clamp(0, widget.allGroups.length - 1);
    _storyIndex = widget.initialStoryIndex
        .clamp(0, widget.allGroups[_userIndex].length - 1);
    _pageController = PageController(initialPage: _userIndex);

    _startTimer();
    _playCurrentMusic();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _pageController.dispose();
    super.dispose();
  }

  List<StoryModel> get _currentGroup => widget.allGroups[_userIndex];
  StoryModel get _currentStory => _currentGroup[_storyIndex];

  Future<void> _playCurrentMusic() async {
    try {
      await _audioPlayer.stop();
      final track = _currentStory.musicTrack;
      if (track != null && track.previewUrl.isNotEmpty) {
        await _audioPlayer.play(track.previewUrl, loop: true);
      }
    } catch (e) {
      debugPrint('Error playing story music: $e');
    }
  }

  void _closeViewer() {
    _reactionOverlayKey.currentState?.clear();
    _timer?.cancel();
    _audioPlayer.stop();
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _currentTick = 0;
    _progress = 0.0;
    _isHolding = false;
    _runTimer();
  }

  void _pauseTimer() {
    if (_isHolding) return;
    _timer?.cancel();
    _audioPlayer.pause();
    setState(() {
      _isHolding = true;
    });
  }

  void _resumeTimer() {
    if (!_isHolding) return;
    setState(() {
      _isHolding = false;
    });
    _audioPlayer.resume();
    _runTimer();
  }

  void _runTimer() {
    _timer?.cancel();
    const interval = Duration(milliseconds: 100);
    _timer = Timer.periodic(interval, (timer) {
      if (!mounted) return;
      _currentTick++;
      setState(() {
        _progress = _currentTick / _totalTicks;
      });

      if (_currentTick >= _totalTicks) {
        _nextStory();
      }
    });
  }

  void _nextStory() {
    _reactionOverlayKey.currentState?.clear();
    if (_storyIndex < _currentGroup.length - 1) {
      setState(() {
        _storyIndex++;
      });
      _playCurrentMusic();
      _startTimer();
    } else if (_userIndex < widget.allGroups.length - 1) {
      final nextUser = _userIndex + 1;
      setState(() {
        _userIndex = nextUser;
        _storyIndex = 0;
      });
      _playCurrentMusic();
      _startTimer();
      _pageController.animateToPage(
        nextUser,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _closeViewer();
    }
  }

  void _previousStory() {
    _reactionOverlayKey.currentState?.clear();
    if (_storyIndex > 0) {
      setState(() {
        _storyIndex--;
      });
      _playCurrentMusic();
      _startTimer();
    } else if (_userIndex > 0) {
      final prevUser = _userIndex - 1;
      setState(() {
        _userIndex = prevUser;
        _storyIndex = 0;
      });
      _playCurrentMusic();
      _startTimer();
      _pageController.animateToPage(
        prevUser,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _closeViewer();
    }
  }

  void _onPageChanged(int newIndex) {
    _reactionOverlayKey.currentState?.clear();
    if (newIndex != _userIndex) {
      setState(() {
        _userIndex = newIndex;
        _storyIndex = 0;
      });
      _playCurrentMusic();
      _startTimer();
    }
  }

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

  void _triggerReaction(String emoji, Offset origin, String storyId) {
    _reactionOverlayKey.currentState?.triggerBurst(emoji, origin: origin);
    ref.read(storyRepositoryProvider).sendStoryReaction(
          storyId: storyId,
          reaction: emoji,
        );
  }

  Widget _buildEmojiButton(StoryModel story, String emoji) {
    return Builder(
      builder: (ctx) {
        return GestureDetector(
          onTap: () {
            final renderBox = ctx.findRenderObject() as RenderBox?;
            Offset? origin;
            if (renderBox != null) {
              origin = renderBox.localToGlobal(
                renderBox.size.center(Offset.zero),
              );
            }
            _triggerReaction(emoji, origin ?? const Offset(200, 600), story.id);
          },
          child: Container(
            width: 42,
            height: 42,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoreEmojiButton(BuildContext context, StoryModel story) {
    return Builder(
      builder: (ctx) {
        return GestureDetector(
          onTap: () {
            final renderBox = ctx.findRenderObject() as RenderBox?;
            Offset? origin;
            if (renderBox != null) {
              origin = renderBox.localToGlobal(
                renderBox.size.center(Offset.zero),
              );
            }
            _showAllEmojisSheet(context, story, origin);
          },
          child: Container(
            width: 42,
            height: 42,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              CupertinoIcons.add,
              color: Colors.white,
              size: 18,
            ),
          ),
        );
      },
    );
  }

  void _showAllEmojisSheet(
      BuildContext context, StoryModel story, Offset? triggerOrigin) {
    _pauseTimer();
    const allEmojis = [
      '❤️', '🔥', '😂', '😮', '😢', '👏',
      '🎉', '😍', '🙌', '✨', '🥳',
      '🥰', '🥺', '😎', '🤩', '🚀', '💯',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Thả biểu cảm',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark,
                          color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(bottomCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  children: allEmojis.map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(bottomCtx);
                        _triggerReaction(
                            emoji, triggerOrigin ?? const Offset(200, 600), story.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      _resumeTimer();
    });
  }

  void _showOwnerViewsSheet(BuildContext context, StoryModel story) {
    _pauseTimer();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomCtx) {
        return SafeArea(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: ref
                .read(storyRepositoryProvider)
                .getStoryReactions(story.id),
            builder: (ctx, snapshot) {
              final reactions = snapshot.data ?? [];
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Người bày tỏ biểu cảm (${reactions.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(CupertinoIcons.xmark,
                              color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(bottomCtx),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    if (isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (reactions.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text(
                            'Chưa có ai thả biểu cảm cho tin này',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: reactions.length,
                          itemBuilder: (context, idx) {
                            final item = reactions[idx];
                            final profile = item['profiles'] as Map? ?? {};
                            final rawName = profile['full_name'] as String?;
                            final username = profile['username'] as String?;
                            final displayName = (rawName != null && rawName.isNotEmpty)
                                ? rawName
                                : (username != null && username.isNotEmpty
                                    ? username
                                    : 'Người dùng');
                            final avatarUrl = profile['avatar_url'] as String?;
                            final emoji = item['reaction'] as String? ?? '❤️';
                            final createdAtStr =
                                item['created_at'] as String?;
                            final createdAt = createdAtStr != null
                                ? DateTime.tryParse(createdAtStr)
                                : null;

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: AppAvatar(
                                imageUrl: avatarUrl,
                                name: displayName,
                                radius: 20,
                              ),
                              title: Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: createdAt != null
                                  ? Text(
                                      createdAt.timeAgo,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                              trailing: Text(
                                emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      _resumeTimer();
    });
  }

  Widget _buildViewerBottomBar(BuildContext context, StoryModel story) {
    const emojis = ['❤️', '🔥', '😂', '😮', '😢', '👏'];

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...emojis.map((emoji) => _buildEmojiButton(story, emoji)),
            _buildMoreEmojiButton(context, story),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerBottomBar(BuildContext context, StoryModel story) {
    return Center(
      child: GestureDetector(
        onTap: () => _showOwnerViewsSheet(context, story),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.sparkles, color: Color(0xFF38BDF8), size: 16),
              SizedBox(width: 8),
              Text(
                'Xem người bày tỏ biểu cảm',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoryPageContent(
      BuildContext context, int userIdx, String? currentUserId) {
    final isCurrentPage = userIdx == _userIndex;
    final userStories = widget.allGroups[userIdx];
    final story = isCurrentPage ? _currentStory : userStories.first;
    final isOwner = currentUserId != null && story.userId == currentUserId;
    final bgColor = _hexToColor(story.backgroundColor);
    final hasMedia = story.mediaUrl != null && story.mediaUrl!.isNotEmpty;

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          _closeViewer();
        }
      },
      onLongPressStart: (_) => _pauseTimer(),
      onLongPressEnd: (_) => _resumeTimer(),
      onLongPressCancel: () => _resumeTimer(),
      onTapUp: (details) {
        if (_isHolding) return;
        final width = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < width / 3) {
          _previousStory();
        } else {
          _nextStory();
        }
      },
      child: Container(
        color: bgColor,
        child: Stack(
          children: [
            // Layer 1: FULLSCREEN IMAGE BACKGROUND (if present)
            if (hasMedia)
              Positioned.fill(
                child: Image.network(
                  story.mediaUrl!,
                  fit: BoxFit.cover,
                ),
              )
            else
              Positioned.fill(
                child: Container(color: bgColor),
              ),

            // Gradient overlay for legibility if media exists
            if (hasMedia)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black54,
                        Colors.transparent,
                        Colors.black54,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

            // Layer 2: Caption Text (Centered on screen)
            if (story.caption != null && story.caption!.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    story.caption!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      shadows: [
                        Shadow(blurRadius: 10, color: Colors.black87),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Top Progress Bar & Header Info
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isHolding ? 0.0 : 1.0,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // Linear progress indicator for userStories
                      Row(
                        children: userStories.asMap().entries.map((entry) {
                          final idx = entry.key;
                          double val = 0.0;
                          if (isCurrentPage) {
                            if (idx < _storyIndex) val = 1.0;
                            if (idx == _storyIndex) val = _progress;
                          } else {
                            val = 0.0;
                          }

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: LinearProgressIndicator(
                                value: val,
                                backgroundColor: Colors.white30,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                                minHeight: 3,
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 10),

                      // User Info & Music Header Row
                      Row(
                        children: [
                          AppAvatar(
                            imageUrl: story.author?.avatarUrl,
                            name: story.author?.displayName ?? 'User',
                            radius: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        story.author?.displayName ?? 'Người dùng',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      story.createdAt.timeAgo,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                if (story.musicTrack != null) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        CupertinoIcons.music_note_2,
                                        size: 12,
                                        color: Color(0xFF38BDF8),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${story.musicTrack!.title} • ${story.musicTrack!.artist}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            shadows: [
                                              Shadow(
                                                  blurRadius: 4,
                                                  color: Colors.black54),
                                            ],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isOwner)
                            IconButton(
                              icon: const Icon(CupertinoIcons.trash,
                                  color: Colors.white70, size: 20),
                              onPressed: () async {
                                _pauseTimer();
                                final confirm = await showCupertinoDialog<bool>(
                                  context: context,
                                  builder: (ctx) => CupertinoAlertDialog(
                                    title: const Text('Xóa tin vĩnh viễn?'),
                                    content: const Text(
                                        'Tin này và toàn bộ ảnh/video đính kèm sẽ bị xóa hoàn toàn khỏi hệ thống lưu trữ.'),
                                    actions: [
                                      CupertinoDialogAction(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Hủy'),
                                      ),
                                      CupertinoDialogAction(
                                        isDestructiveAction: true,
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Xóa'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm != true) {
                                  _resumeTimer();
                                  return;
                                }

                                try {
                                  await ref
                                      .read(storyRepositoryProvider)
                                      .deleteStory(story.id, mediaUrl: story.mediaUrl);
                                  ref.invalidate(activeStoriesProvider);
                                  ref.invalidate(userStoriesProvider(story.userId));
                                  final currentUserId = ref.read(currentUserIdProvider);
                                  if (currentUserId != null && currentUserId != story.userId) {
                                    ref.invalidate(userStoriesProvider(currentUserId));
                                  }
                                  if (context.mounted) {
                                    ToastService.showSuccess(context, 'Đã xóa tin thành công');
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ToastService.showError(context, 'Lỗi khi xóa tin: $e');
                                  }
                                }
                                _closeViewer();
                              },
                            ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.xmark,
                                color: Colors.white, size: 22),
                            onPressed: _closeViewer,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Action Bar: Reactions & Reply (for visitors) or Stats (for owner)
            Positioned(
              bottom: 16,
              left: 14,
              right: 14,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isHolding ? 0.0 : 1.0,
                child: SafeArea(
                  top: false,
                  child: isOwner
                      ? _buildOwnerBottomBar(context, story)
                      : _buildViewerBottomBar(context, story),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.allGroups.isEmpty) return const SizedBox.shrink();

    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: StoryReactionBurstOverlay(
        key: _reactionOverlayKey,
        child: PageView.builder(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          onPageChanged: _onPageChanged,
          itemCount: widget.allGroups.length,
          itemBuilder: (context, userIdx) {
            return AnimatedBuilder(
              animation: _pageController,
              child: _buildStoryPageContent(context, userIdx, currentUserId),
              builder: (context, child) {
                double page = _userIndex.toDouble();
                if (_pageController.hasClients &&
                    _pageController.position.haveDimensions &&
                    _pageController.page != null) {
                  page = _pageController.page!;
                }

                final double delta = userIdx - page;

                // If page is completely offscreen (> 1.0 or < -1.0), don't render
                if (delta.abs() > 1.0) {
                  return const SizedBox.shrink();
                }

                // iOS Card Slide & Interactive Scale Transition:
                final double progress = delta.abs().clamp(0.0, 1.0);
                const double minScale = 0.85;
                final double scale = 1.0 - ((1.0 - minScale) * progress);
                final double opacity = (1.0 - (0.25 * progress)).clamp(0.0, 1.0);
                final double radius = 24.0 * progress;

                return Transform.scale(
                  scale: scale,
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radius),
                        boxShadow: progress > 0.02
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5 * progress),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(radius),
                        child: child,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
