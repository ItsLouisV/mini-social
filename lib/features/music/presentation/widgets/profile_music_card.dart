import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../domain/music_track_model.dart';

class ProfileMusicCard extends StatefulWidget {
  final MusicTrackModel track;
  final bool isOwner;
  final bool autoPlay;
  final bool compact;
  final VoidCallback? onDelete;

  const ProfileMusicCard({
    super.key,
    required this.track,
    this.isOwner = false,
    this.autoPlay = false,
    this.compact = false,
    this.onDelete,
  });

  @override
  State<ProfileMusicCard> createState() => _ProfileMusicCardState();
}

class _ProfileMusicCardState extends State<ProfileMusicCard>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _rotationController;
  bool _isPlaying = false;
  bool _isLoadingAudio = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.playing ||
              state == PlayerState.paused ||
              state == PlayerState.completed) {
            _isLoadingAudio = false;
          }
        });
        if (_isPlaying) {
          _rotationController.repeat();
        } else {
          _rotationController.stop();
        }
      }
    });

    if (widget.autoPlay && widget.track.previewUrl.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _playAudioFast();
        }
      });
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudioFast() async {
    if (widget.track.previewUrl.isEmpty) return;
    try {
      setState(() => _isLoadingAudio = true);
      await _audioPlayer.setSourceUrl(widget.track.previewUrl);
      await _audioPlayer.resume();
    } catch (_) {
      try {
        await _audioPlayer.play(UrlSource(widget.track.previewUrl));
      } catch (_) {}
    } finally {
      if (mounted && _isPlaying) {
        setState(() => _isLoadingAudio = false);
      }
    }
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _playAudioFast();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCompact = widget.compact;

    return Container(
      margin: isCompact
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: isCompact
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCompact
            ? Colors.black.withValues(alpha: 0.45)
            : (isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.8)
                : const Color(0xFFF1F5F9).withValues(alpha: 0.9)),
        borderRadius: BorderRadius.circular(isCompact ? 20 : 16),
        border: Border.all(
          color: isCompact
              ? Colors.white24
              : const Color(0xFF38BDF8).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: isCompact
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: isCompact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          // Vinyl Disk with Cover Art
          GestureDetector(
            onTap: _toggleAudio,
            child: RotationTransition(
              turns: _rotationController,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: isCompact ? 28 : 42,
                    height: isCompact ? 28 : 42,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black87,
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(isCompact ? 14 : 20),
                    child: CachedNetworkImage(
                      imageUrl: widget.track.getHighResArtworkUrl(100),
                      width: isCompact ? 24 : 36,
                      height: isCompact ? 24 : 36,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.grey.shade400),
                      errorWidget: (_, __, ___) => Icon(
                        CupertinoIcons.music_note,
                        color: Colors.white,
                        size: isCompact ? 14 : 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: isCompact ? 8 : 12),

          // Title & Artist
          Flexible(
            child: GestureDetector(
              onTap: _toggleAudio,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: isCompact ? MainAxisSize.min : MainAxisSize.max,
                    children: [
                      Icon(
                        CupertinoIcons.music_note_2,
                        size: isCompact ? 11 : 13,
                        color: const Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          widget.track.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isCompact ? 12 : 13,
                            color: isCompact ? Colors.white : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (!isCompact || widget.track.artist.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      widget.track.artist,
                      style: TextStyle(
                        fontSize: isCompact ? 10 : 11,
                        color: isCompact
                            ? Colors.white70
                            : theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Play / Pause / Loading Button
          IconButton(
            padding: isCompact ? EdgeInsets.zero : const EdgeInsets.all(8),
            constraints: isCompact ? const BoxConstraints() : null,
            onPressed: _toggleAudio,
            icon: _isLoadingAudio
                ? SizedBox(
                    width: isCompact ? 14 : 18,
                    height: isCompact ? 14 : 18,
                    child: const CupertinoActivityIndicator(
                      color: Color(0xFF38BDF8),
                    ),
                  )
                : Icon(
                    _isPlaying
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                    color: const Color(0xFF38BDF8),
                    size: isCompact ? 16 : 22,
                  ),
          ),

          // Optional Delete (if Profile Owner)
          if (widget.isOwner && widget.onDelete != null)
            IconButton(
              padding: isCompact ? EdgeInsets.zero : const EdgeInsets.all(8),
              constraints: isCompact ? const BoxConstraints() : null,
              onPressed: () {
                _audioPlayer.stop();
                widget.onDelete!();
              },
              icon: Icon(
                CupertinoIcons.xmark_circle_fill,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: isCompact ? 14 : 18,
              ),
            ),
        ],
      ),
    );
  }
}
