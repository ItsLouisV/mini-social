import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class VoiceMessageBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  final Color themeColor;
  final String? contentLabel;

  const VoiceMessageBubble({
    super.key,
    required this.audioUrl,
    required this.isMe,
    required this.themeColor,
    this.contentLabel,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  bool _isLoaded = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackRate = 1.0;

  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _completeSubscription;

  // Dải sóng âm cao thấp thất thường nhấp nhô ngẫu nhiên tự nhiên
  static const List<double> _waveAmplitudes = [
    0.45, 0.10, 0.65, 0.50, 1.20, 1.35, 0.85, 0.35, 0.15, 0.60,
    0.45, 0.85, 1.20, 0.95, 0.50, 0.10, 0.30, 0.70, 0.45, 0.95,
    0.60, 0.90, 1.35, 0.85, 0.30, 0.50, 0.55, 0.90, 0.30, 0.65
  ];

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _durationSubscription = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _positionSubscription = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _stateSubscription = _player.onPlayerStateChanged.listen((s) {
      if (mounted) {
        setState(() {
          _isPlaying = s == PlayerState.playing;
        });
      }
    });

    _completeSubscription = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    _completeSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        if (!_isLoaded) {
          await _player.setSourceUrl(widget.audioUrl);
          _isLoaded = true;
        }
        await _player.setPlaybackRate(_playbackRate);
        await _player.resume();
      }
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  void _toggleSpeed() {
    setState(() {
      if (_playbackRate == 1.0) {
        _playbackRate = 1.5;
      } else if (_playbackRate == 1.5) {
        _playbackRate = 2.0;
      } else {
        _playbackRate = 1.0;
      }
    });
    if (_isPlaying) {
      _player.setPlaybackRate(_playbackRate);
    }
  }

  void _seekToProgress(double progressFraction) {
    if (_duration > Duration.zero) {
      final targetMs = (_duration.inMilliseconds * progressFraction).round();
      _player.seek(Duration(milliseconds: targetMs));
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _getInitialTimeLabel() {
    final label = widget.contentLabel;
    if (label != null) {
      final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(label);
      if (match != null) {
        final m = int.parse(match.group(1)!);
        final s = match.group(2)!;
        return '$m:$s';
      }
    }
    return '0:00';
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isMe ? Colors.white : widget.themeColor;
    final inactiveColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.35)
        : widget.themeColor.withValues(alpha: 0.25);
    final textColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.9)
        : Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;

    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: 185,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Nút Play / Pause nhỏ nhắn (30px)
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.25)
                    : widget.themeColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying
                    ? CupertinoIcons.pause_fill
                    : CupertinoIcons.play_fill,
                color: activeColor,
                size: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 2. Dải sóng âm
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final RenderBox? box = context.findRenderObject() as RenderBox?;
                if (box != null) {
                  final localPos = details.localPosition.dx;
                  final width = box.size.width;
                  if (width > 0) {
                    _seekToProgress((localPos / width).clamp(0.0, 1.0));
                  }
                }
              },
              onHorizontalDragUpdate: (details) {
                final RenderBox? box = context.findRenderObject() as RenderBox?;
                if (box != null) {
                  final localPos = details.localPosition.dx;
                  final width = box.size.width;
                  if (width > 0) {
                    _seekToProgress((localPos / width).clamp(0.0, 1.0));
                  }
                }
              },
              child: SizedBox(
                height: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(_waveAmplitudes.length, (index) {
                    final barProgress = index / (_waveAmplitudes.length - 1);
                    final isPlayed = barProgress <= progress;
                    final height = 4.0 + (_waveAmplitudes[index] * 18.0);

                    return Container(
                      width: 2.0,
                      height: height,
                      margin: const EdgeInsets.symmetric(horizontal: 0.6),
                      decoration: BoxDecoration(
                        color: isPlayed ? activeColor : inactiveColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),

          // 3. Cột Thời gian & Tốc độ
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _isPlaying
                    ? _formatDuration(_position)
                    : (_duration > Duration.zero
                        ? _formatDuration(_duration)
                        : _getInitialTimeLabel()),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: _toggleSpeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: widget.isMe
                        ? Colors.white.withValues(alpha: 0.2)
                        : widget.themeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_playbackRate == 1.0 ? '1' : _playbackRate}x',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: activeColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
