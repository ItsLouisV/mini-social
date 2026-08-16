import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/date_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/story_model.dart';
import '../../providers/story_provider.dart';

class StoryViewerModal extends ConsumerStatefulWidget {
  final List<StoryModel> stories;
  final int initialIndex;

  const StoryViewerModal({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  static void show(BuildContext context, {required List<StoryModel> stories, int initialIndex = 0}) {
    if (stories.isEmpty) return;
    showGeneralDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'StoryViewer',
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => StoryViewerModal(stories: stories, initialIndex: initialIndex),
    );
  }

  @override
  ConsumerState<StoryViewerModal> createState() => _StoryViewerModalState();
}

class _StoryViewerModalState extends ConsumerState<StoryViewerModal> {
  late int _currentIndex;
  Timer? _timer;
  double _progress = 0.0;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _startTimer();
    _playCurrentMusic();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playCurrentMusic() async {
    try {
      await _audioPlayer.stop();
      final track = widget.stories[_currentIndex].musicTrack;
      if (track != null && track.previewUrl.isNotEmpty) {
        await _audioPlayer.setSourceUrl(track.previewUrl);
        await _audioPlayer.resume();
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
    const totalTicks = 150; // 15 seconds total

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
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _playCurrentMusic();
      _startTimer();
    } else {
      _closeViewer();
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _playCurrentMusic();
      _startTimer();
    } else {
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

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) return const SizedBox.shrink();

    final currentStory = widget.stories[_currentIndex];
    final currentUserId = ref.watch(currentUserIdProvider);
    final isOwner = currentUserId != null && currentStory.userId == currentUserId;
    final bgColor = _hexToColor(currentStory.backgroundColor);

    final hasMedia = currentStory.mediaUrl != null && currentStory.mediaUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
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
                    currentStory.mediaUrl!,
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

              // Layer 2: Caption Text (Centered on screen, transparent)
              if (currentStory.caption != null && currentStory.caption!.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      currentStory.caption!,
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
                      // Linear progress indicator
                      Row(
                        children: widget.stories.asMap().entries.map((entry) {
                          final idx = entry.key;
                          double val = 0.0;
                          if (idx < _currentIndex) val = 1.0;
                          if (idx == _currentIndex) val = _progress;

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: LinearProgressIndicator(
                                value: val,
                                backgroundColor: Colors.white30,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
                            imageUrl: currentStory.author?.avatarUrl,
                            name: currentStory.author?.displayName ?? 'User',
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
                                        currentStory.author?.displayName ?? 'Người dùng',
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
                                      currentStory.createdAt.timeAgo,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                if (currentStory.musicTrack != null) ...[
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
                                          '${currentStory.musicTrack!.title} • ${currentStory.musicTrack!.artist}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            shadows: [
                                              Shadow(blurRadius: 4, color: Colors.black54),
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
                              icon: const Icon(CupertinoIcons.trash, color: Colors.white70, size: 20),
                              onPressed: () async {
                                await ref.read(storyRepositoryProvider).deleteStory(currentStory.id);
                                ref.invalidate(activeStoriesProvider);
                                _closeViewer();
                              },
                            ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 22),
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
      ),
    );
  }
}
