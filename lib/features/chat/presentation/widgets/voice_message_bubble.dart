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
  bool _showStt = false;
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

    final hasCustomSttText = widget.contentLabel != null &&
        !RegExp(r'^\d{1,2}:\d{2}$').hasMatch(widget.contentLabel!.trim());

    return Container(
      width: 275,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Nút Play / Pause nhỏ nhắn (30px)
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 40,
                  height: 40,
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
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 5),

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
                    height: 38,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final availableWidth = constraints.maxWidth;
                        final count = _waveAmplitudes.length;
                        final totalWidthPerBar = availableWidth / count;
                        final barWidth = (totalWidthPerBar * 0.6).clamp(1.2, 3.0);
                        final margin = (totalWidthPerBar * 0.2).clamp(0.2, 1.0);

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List.generate(count, (index) {
                            final barStart = index / count;
                            final barEnd = (index + 1) / count;

                            final double fill;
                            if (progress <= barStart) {
                              fill = 0.0;
                            } else if (progress >= barEnd) {
                              fill = 1.0;
                            } else {
                              fill = (progress - barStart) / (barEnd - barStart);
                            }

                            final barColor = Color.lerp(
                              inactiveColor,
                              activeColor,
                              fill.clamp(0.0, 1.0),
                            )!;
                            final height = 6.0 + (_waveAmplitudes[index] * 28.0);

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              curve: Curves.easeOut,
                              width: barWidth,
                              height: height,
                              margin: EdgeInsets.symmetric(horizontal: margin),
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),

              // 3. Cột Thời gian & Nút bật/tắt STT (chữ A)
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
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showStt = !_showStt;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _showStt
                            ? (widget.isMe
                                ? Colors.white.withValues(alpha: 0.35)
                                : widget.themeColor.withValues(alpha: 0.25))
                            : (widget.isMe
                                ? Colors.white.withValues(alpha: 0.2)
                                : widget.themeColor.withValues(alpha: 0.12)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'A',
                        style: TextStyle(
                          fontSize: 14,
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

          // 4. Khung hiển thị văn bản STT bên dưới tin nhắn thoại khi bấm "A"
          if (_showStt) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.16)
                    : widget.themeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    CupertinoIcons.text_quote,
                    size: 13,
                    color: activeColor.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hasCustomSttText
                          ? widget.contentLabel!
                          : 'Đang chờ chuyển văn bản...',
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor,
                        height: 1.35,
                        fontStyle: hasCustomSttText
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
