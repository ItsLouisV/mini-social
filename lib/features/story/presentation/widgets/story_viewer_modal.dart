import 'dart:async';
import 'dart:math' as math;
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
  bool _isSwiping = false;
  bool _isSheetOpen = false;
  bool _isMuted = false;
  int? _pendingUserIndex;
  late final AppAudioPlayer _audioPlayer;
  final GlobalKey<StoryReactionBurstOverlayState> _reactionOverlayKey =
      GlobalKey<StoryReactionBurstOverlayState>();

  bool get _isPlaybackPaused => _isHolding || _isSwiping || _isSheetOpen;

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
      if (_isPlaybackPaused) return;
      final track = _currentStory.musicTrack;
      if (track != null && track.previewUrl.isNotEmpty) {
        await _audioPlayer.play(track.previewUrl, loop: true);
        // Áp dụng trạng thái mute: volume=0 nếu đang tắt tiếng
        await _audioPlayer.setVolume(_isMuted ? 0.0 : 1.0);
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

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    // Không pause nhạc — chỉ thay đổi âm lượng để nhạc & tin luôn đồng bộ.
    // Ví dụ: nhạc ABCDE, đang ở B thì tắt tiếng → nhạc vẫn chạy đến E (volume=0),
    // khi bật lại thì nhạc tiếp tục đúng vị trí, khớp với tiến trình của tin.
    _audioPlayer.setVolume(_isMuted ? 0.0 : 1.0);
  }

  void _pausePlayback() {
    _timer?.cancel();
    _audioPlayer.pause();
  }

  void _resumePlayback() {
    if (_isPlaybackPaused) return;
    if (!_isMuted) {
      _audioPlayer.resume();
    }
    _runTimer();
  }

  void _onLongPressStart() {
    setState(() {
      _isHolding = true;
    });
    _pausePlayback();
  }

  void _onLongPressEnd() {
    setState(() {
      _isHolding = false;
    });
    _resumePlayback();
  }

  void _onScrollStart(ScrollStartNotification notification) {
    if (notification.metrics.axis == Axis.horizontal && !_isSwiping) {
      _isSwiping = true;
      _pausePlayback();
    }
  }

  void _handleScrollSettled() {
    if (!mounted) return;
    _isSwiping = false;

    final double? page =
        _pageController.hasClients && _pageController.page != null
            ? _pageController.page
            : null;
    final int targetIndex = (page != null
            ? page.round()
            : (_pendingUserIndex ?? _userIndex))
        .clamp(0, widget.allGroups.length - 1);
    _pendingUserIndex = null;

    if (targetIndex != _userIndex) {
      setState(() {
        _userIndex = targetIndex;
        _storyIndex = 0;
      });
      _playCurrentMusic();
      _startTimer();
    } else {
      _resumePlayback();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _currentTick = 0;
    _progress = 0.0;
    _runTimer();
  }

  void _runTimer() {
    _timer?.cancel();
    if (_isPlaybackPaused) return;
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
      _isSwiping = true;
      _pausePlayback();
      _pageController
          .animateToPage(
        nextUser,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      )
          .then((_) {
        if (mounted && _isSwiping) {
          _handleScrollSettled();
        }
      });
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
      _isSwiping = true;
      _pausePlayback();
      _pageController
          .animateToPage(
        prevUser,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      )
          .then((_) {
        if (mounted && _isSwiping) {
          _handleScrollSettled();
        }
      });
    } else {
      _closeViewer();
    }
  }

  void _onPageChanged(int newIndex) {
    _reactionOverlayKey.currentState?.clear();
    _pendingUserIndex = newIndex;
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
    _isSheetOpen = true;
    _pausePlayback();
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
      _isSheetOpen = false;
      _resumePlayback();
    });
  }

  void _showOwnerViewsSheet(BuildContext context, StoryModel story) {
    _isSheetOpen = true;
    _pausePlayback();

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
      _isSheetOpen = false;
      _resumePlayback();
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
      onLongPressStart: (_) => _onLongPressStart(),
      onLongPressEnd: (_) => _onLongPressEnd(),
      onLongPressCancel: () => _onLongPressEnd(),
      onTapUp: (details) {
        if (_isHolding || _isSwiping) return;
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppAvatar(
                                imageUrl: story.author?.avatarUrl,
                                name: story.author?.displayName ?? 'User',
                                radius: 18,
                              ),
                              if (story.musicTrack != null) ...[
                                const SizedBox(height: 6),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _toggleMute,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.55),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _isMuted
                                            ? Colors.white24
                                            : const Color(0xFF38BDF8)
                                                .withValues(alpha: 0.7),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.35),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      _isMuted
                                          ? CupertinoIcons.speaker_slash_fill
                                          : CupertinoIcons.speaker_2_fill,
                                      color: _isMuted
                                          ? Colors.white60
                                          : const Color(0xFF38BDF8),
                                      size: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ],
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
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(
                                        CupertinoIcons.music_note_2,
                                        size: 12,
                                        color: Color(0xFF38BDF8),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: StoryMarqueeText(
                                          text:
                                              '${story.musicTrack!.title} • ${story.musicTrack!.artist}',
                                          isPaused: _isPlaybackPaused,
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
                                _isSheetOpen = true;
                                _pausePlayback();
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

                                _isSheetOpen = false;
                                if (confirm != true) {
                                  _resumePlayback();
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
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification notification) {
            if (notification.depth != 0) return false;

            if (notification is ScrollStartNotification) {
              _onScrollStart(notification);
            } else if (notification is ScrollEndNotification) {
              _handleScrollSettled();
            }
            return false;
          },
          child: PageView.builder(
            controller: _pageController,
            clipBehavior: Clip.none,
            physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
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

                  final double maxPage =
                      (widget.allGroups.length - 1).toDouble();
                  final double clampedPage = page.clamp(0.0, maxPage);
                  final double delta = userIdx - clampedPage;

                  // If page is completely offscreen (>= 1.0 or <= -1.0), don't render
                  if (delta.abs() >= 1.0) {
                    return const SizedBox.shrink();
                  }

                  // 3D Cube flip rotation (Instagram-style)
                  // Angle ranges from -pi/2 (-90°) to +pi/2 (+90°)
                  final double angle =
                      (delta * (math.pi / 2)).clamp(-math.pi / 2, math.pi / 2);

                  // Pivot point:
                  // delta < 0: page is to the left, pivoting around its right edge (seam)
                  // delta > 0: page is to the right, pivoting around its left edge (seam)
                  // delta == 0: centered page
                  final Alignment alignment = delta < 0
                      ? Alignment.centerRight
                      : (delta > 0 ? Alignment.centerLeft : Alignment.center);

                  // Perspective transformation matrix
                  final Matrix4 transform = Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(angle);

                  // 3D depth shadow overlay as the cube face turns away from camera
                  final double shadowOpacity =
                      (delta.abs() * 0.55).clamp(0.0, 0.7);

                  return Transform(
                    transform: transform,
                    alignment: alignment,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        child!,
                        if (shadowOpacity > 0.01)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: delta < 0
                                        ? Alignment.centerLeft
                                        : Alignment.centerRight,
                                    end: delta < 0
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    colors: [
                                      Colors.black.withValues(
                                          alpha: shadowOpacity),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Marquee text widget for song title / artist
/// If text fits within bounds, renders static text.
/// If text overflows, smoothly scrolls with a pause at the start and seamless loop.
class StoryMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final bool isPaused;
  final double velocity;

  const StoryMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.isPaused = false,
    this.velocity = 32.0,
  });

  @override
  State<StoryMarqueeText> createState() => _StoryMarqueeTextState();
}

class _StoryMarqueeTextState extends State<StoryMarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _textWidth = 0.0;
  double _containerWidth = 0.0;
  static const double _gap = 36.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(StoryMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _containerWidth = 0.0;
      _textWidth = 0.0;
      _controller.reset();
    } else if (oldWidget.isPaused != widget.isPaused) {
      if (widget.isPaused) {
        _controller.stop();
      } else {
        if (_controller.duration != null &&
            _controller.duration! > Duration.zero &&
            !_controller.isAnimating) {
          _controller.repeat();
        }
      }
    }
  }

  void _measureAndSetup(double maxWidth) {
    if ((_containerWidth - maxWidth).abs() < 1.0 && _textWidth > 0) return;
    _containerWidth = maxWidth;

    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    _textWidth = textPainter.width;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_textWidth > _containerWidth && _containerWidth > 0) {
        final totalDistance = _textWidth + _gap;
        const pauseMs = 1500;
        final scrollMs = (totalDistance / widget.velocity * 1000).round();
        final totalMs = pauseMs + scrollMs;

        _controller.duration = Duration(milliseconds: totalMs);
        if (!widget.isPaused && !_controller.isAnimating) {
          _controller.repeat();
        }
      } else {
        _controller.stop();
        _controller.reset();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _measureAndSetup(constraints.maxWidth);

        if (_textWidth <= constraints.maxWidth || constraints.maxWidth <= 0) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        final totalDistance = _textWidth + _gap;
        const pauseMs = 1500;
        final scrollMs = (totalDistance / widget.velocity * 1000).round();
        final totalMs = pauseMs + scrollMs;
        final pauseFraction =
            totalMs > 0 ? (pauseMs / totalMs).clamp(0.0, 0.8) : 0.0;

        return ShaderMask(
          shaderCallback: (rect) {
            return const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0.0, 0.04, 0.94, 1.0],
            ).createShader(rect);
          },
          blendMode: BlendMode.dstIn,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                double curveProgress = 0.0;
                if (t > pauseFraction) {
                  curveProgress = (t - pauseFraction) / (1.0 - pauseFraction);
                }
                final double offset = curveProgress * totalDistance;

                return Transform.translate(
                  offset: Offset(-offset, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.text, style: widget.style),
                  const SizedBox(width: _gap),
                  Text(widget.text, style: widget.style),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
