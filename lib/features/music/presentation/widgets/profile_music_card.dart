import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../domain/music_track_model.dart';

class ProfileMusicCard extends StatefulWidget {
  final MusicTrackModel track;
  final bool isOwner;
  final VoidCallback? onDelete;

  const ProfileMusicCard({
    super.key,
    required this.track,
    this.isOwner = false,
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
        });
        if (_isPlaying) {
          _rotationController.repeat();
        } else {
          _rotationController.stop();
        }
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(widget.track.previewUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.8)
            : const Color(0xFFF1F5F9).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
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
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black87,
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: widget.track.getHighResArtworkUrl(100),
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.grey.shade400),
                      errorWidget: (_, __, ___) => const Icon(
                        CupertinoIcons.music_note,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Artist
          Expanded(
            child: GestureDetector(
              onTap: _toggleAudio,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.music_note_2,
                        size: 13,
                        color: Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.track.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.track.artist,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // Play / Pause Button
          IconButton(
            onPressed: _toggleAudio,
            icon: Icon(
              _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
              color: const Color(0xFF38BDF8),
              size: 22,
            ),
          ),

          // Optional Delete (if Profile Owner)
          if (widget.isOwner && widget.onDelete != null)
            IconButton(
              onPressed: () {
                _audioPlayer.stop();
                widget.onDelete!();
              },
              icon: Icon(
                CupertinoIcons.xmark_circle_fill,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: 18,
              ),
            ),
        ],
      ),
    );
  }
}
