import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/date_extension.dart';
import '../../../../core/services/audio_player/app_audio_player.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/story_model.dart';
import '../../providers/story_provider.dart';

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
  late final AppAudioPlayer _audioPlayer;

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
    _timer?.cancel();
    _audioPlayer.stop();
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _progress = 0.0;
    const interval = Duration(milliseconds: 100);
    const totalTicks = 250; // 25 seconds total (250 * 100ms)

    int currentTick = 0;
    _timer = Timer.periodic(interval, (timer) {
      if (!mounted) return;
      currentTick++;
      setState(() {
        _progress = currentTick / totalTicks;
      });

      if (currentTick >= totalTicks) {
        _nextStory();
      }
    });
  }

  void _nextStory() {
    if (_storyIndex < _currentGroup.length - 1) {
      setState(() {
        _storyIndex++;
      });
      _playCurrentMusic();
      _startTimer();
    } else if (_userIndex < widget.allGroups.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.fastOutSlowIn,
      );
    } else {
      _closeViewer();
    }
  }

  void _previousStory() {
    if (_storyIndex > 0) {
      setState(() {
        _storyIndex--;
      });
      _playCurrentMusic();
      _startTimer();
    } else if (_userIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.fastOutSlowIn,
      );
    } else {
      _closeViewer();
    }
  }

  void _onPageChanged(int newIndex) {
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

  Widget _buildStoryPageContent(
      BuildContext context, int userIdx, String? currentUserId) {
    final isCurrentPage = userIdx == _userIndex;
    final userStories = widget.allGroups[userIdx];
    final story = isCurrentPage ? _currentStory : userStories.first;
    final isOwner = currentUserId != null && story.userId == currentUserId;
    final bgColor = _hexToColor(story.backgroundColor);
    final hasMedia = story.mediaUrl != null && story.mediaUrl!.isNotEmpty;

    return GestureDetector(
      onTapUp: (details) {
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
                              await ref
                                  .read(storyRepositoryProvider)
                                  .deleteStory(story.id);
                              ref.invalidate(activeStoriesProvider);
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
      body: PageView.builder(
        controller: _pageController,
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
              if (delta.abs() >= 1.0) {
                return const SizedBox.shrink();
              }

              // Ultra-smooth 3D Cube Box Rotation (Instagram / Snapchat style)
              final double angle = delta * (3.141592653589793 / 2);
              final alignment =
                  delta >= 0 ? Alignment.centerLeft : Alignment.centerRight;

              // Gentle opacity fade as cube turns away to prevent visual pops
              final double opacity = (1.0 - (delta.abs() * 0.4)).clamp(0.0, 1.0);

              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.0008) // smooth 3D perspective depth ratio
                ..rotateY(angle);

              return Transform(
                transform: transform,
                alignment: alignment,
                child: Opacity(
                  opacity: opacity,
                  child: child,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
