import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

class StoryReactionBurstOverlay extends StatefulWidget {
  final Widget child;

  const StoryReactionBurstOverlay({
    super.key,
    required this.child,
  });

  static StoryReactionBurstOverlayState? of(BuildContext context) {
    return context.findAncestorStateOfType<StoryReactionBurstOverlayState>();
  }

  @override
  State<StoryReactionBurstOverlay> createState() =>
      StoryReactionBurstOverlayState();
}

class _Particle {
  final String emoji;
  final Offset startOffset;
  final double horizontalDelta;
  final double verticalTravel;
  final double swayFrequency;
  final double swayPhase;
  final double size;
  final double maxRotation;
  final int createdAtMs;
  final int durationMs;
  final int delayMs;

  _Particle({
    required this.emoji,
    required this.startOffset,
    required this.horizontalDelta,
    required this.verticalTravel,
    required this.swayFrequency,
    required this.swayPhase,
    required this.size,
    required this.maxRotation,
    required this.createdAtMs,
    required this.durationMs,
    required this.delayMs,
  });
}

class StoryReactionBurstOverlayState extends State<StoryReactionBurstOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final Stopwatch _stopwatch = Stopwatch();
  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    if (_particles.isEmpty) {
      _stopAnimation();
      return;
    }

    final nowMs = _stopwatch.elapsedMilliseconds;
    setState(() {
      _particles.removeWhere(
        (p) => (nowMs - p.createdAtMs) >= (p.delayMs + p.durationMs),
      );
      if (_particles.isEmpty) {
        _stopAnimation();
      }
    });
  }

  void _stopAnimation() {
    if (_ticker.isActive) {
      _ticker.stop();
    }
    _stopwatch.stop();
    _stopwatch.reset();
  }

  /// Remove all active particles immediately (e.g. when switching stories or closing)
  void clear() {
    if (_particles.isNotEmpty) {
      setState(() {
        _particles.clear();
      });
    }
    _stopAnimation();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  /// Trigger a burst of floating particles from a specific origin
  void triggerBurst(String emoji, {Offset? origin}) {
    HapticFeedback.lightImpact();

    if (!_stopwatch.isRunning) {
      _stopwatch.reset();
      _stopwatch.start();
    }
    if (!_ticker.isActive) {
      _ticker.start();
    }

    final size = MediaQuery.of(context).size;
    final start = origin ?? Offset(size.width * 0.75, size.height * 0.88);
    final nowMs = _stopwatch.elapsedMilliseconds;
    const particleCount = 16;

    // Cap total particles to 48 so performance stays ultra-smooth (60-120 fps)
    if (_particles.length > 32) {
      _particles.removeRange(0, _particles.length - 32);
    }

    for (int i = 0; i < particleCount; i++) {
      final horizontalSpread = (_random.nextDouble() - 0.5) * 130.0;
      final verticalTravel = 260.0 + _random.nextDouble() * 300.0;
      final swayFreq = 1.6 + _random.nextDouble() * 2.0;
      final swayPhase = _random.nextDouble() * math.pi * 2;
      final particleSize = 22.0 + _random.nextDouble() * 16.0;
      final rotation = (_random.nextDouble() - 0.5) * 0.6;
      final delayMs = (_random.nextDouble() * 200).toInt();
      final durationMs = 1200 + (_random.nextDouble() * 400).toInt();

      _particles.add(
        _Particle(
          emoji: emoji,
          startOffset: start + Offset((_random.nextDouble() - 0.5) * 20, 0),
          horizontalDelta: horizontalSpread,
          verticalTravel: verticalTravel,
          swayFrequency: swayFreq,
          swayPhase: swayPhase,
          size: particleSize,
          maxRotation: rotation,
          createdAtMs: nowMs,
          durationMs: durationMs,
          delayMs: delayMs,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_particles.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _BurstPainter(
                  particles: List.unmodifiable(_particles),
                  currentMs: _stopwatch.elapsedMilliseconds,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BurstPainter extends CustomPainter {
  final List<_Particle> particles;
  final int currentMs;

  _BurstPainter({
    required this.particles,
    required this.currentMs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final elapsed = currentMs - p.createdAtMs;
      if (elapsed < p.delayMs) continue;

      final flightMs = elapsed - p.delayMs;
      if (flightMs >= p.durationMs) continue;

      final normalizedT = (flightMs / p.durationMs).clamp(0.0, 1.0);

      // Decelerating upward movement
      final upwardProgress = Curves.decelerate.transform(normalizedT);
      final currentY = p.startOffset.dy - (upwardProgress * p.verticalTravel);

      // Sinusoidal horizontal sway
      final currentX = p.startOffset.dx +
          (p.horizontalDelta * upwardProgress) +
          (math.sin(normalizedT * p.swayFrequency * math.pi + p.swayPhase) *
              20.0);

      // Scale: Pop in quickly, then gently glide
      double scale = 1.0;
      if (normalizedT < 0.15) {
        scale = (normalizedT / 0.15) * 1.25;
      } else if (normalizedT < 0.3) {
        scale = 1.25 - ((normalizedT - 0.15) / 0.15) * 0.25;
      } else {
        scale = 1.0 - ((normalizedT - 0.3) / 0.7) * 0.35;
      }

      // Opacity: Fade out smoothly towards the top
      double opacity = 1.0;
      if (normalizedT > 0.5) {
        opacity = (1.0 - ((normalizedT - 0.5) / 0.5)).clamp(0.0, 1.0);
      }

      if (opacity <= 0.01) continue;

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(p.maxRotation * math.sin(normalizedT * math.pi));
      canvas.scale(scale);

      final textSpan = TextSpan(
        text: p.emoji,
        style: TextStyle(
          fontSize: p.size,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) => true;
}
