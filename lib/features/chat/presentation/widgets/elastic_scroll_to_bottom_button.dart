import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ElasticScrollToBottomButton extends StatefulWidget {
  final VoidCallback onTap;
  final int unreadCount;
  final Color? themeColor;

  const ElasticScrollToBottomButton({
    super.key,
    required this.onTap,
    required this.unreadCount,
    this.themeColor,
  });

  @override
  State<ElasticScrollToBottomButton> createState() => _ElasticScrollToBottomButtonState();
}

class _ElasticScrollToBottomButtonState extends State<ElasticScrollToBottomButton>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration? _lastElapsed;
  late VelocityTracker _velocityTracker;

  // Spring coefficients for physics simulation
  static const double kDragStiffness = 180.0;
  static const double kDragDamping = 8.0;
  static const double kScaleStiffness = 240.0;
  static const double kScaleDamping = 10.0;

  // Drag physics states
  Offset _pointerStartGlobalPosition = Offset.zero;
  Offset _dragOffsetAccumulated = Offset.zero;
  Offset _dragPosition = Offset.zero;
  Offset _dragVelocity = Offset.zero;
  Offset _dragTarget = Offset.zero;

  // Scale physics states
  double _scale = 1.0;
  double _scaleVelocity = 0.0;
  double _scaleTarget = 1.0;

  bool _isPressed = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _startTicker() {
    if (!_ticker.isActive) {
      _lastElapsed = null;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == null) {
      _lastElapsed = elapsed;
      return;
    }

    double dt = (elapsed.inMicroseconds - _lastElapsed!.inMicroseconds) / 1000000.0;
    _lastElapsed = elapsed;

    // Guard against massive time jumps due to lag spikes which could destabilize numerical integration
    if (dt > 0.03) dt = 0.03;
    if (dt <= 0.0) return;

    bool dragSettled = true;
    bool scaleSettled = true;

    // 1. Drag spring physics (only updates when user is NOT actively pulling the button)
    if (!_isDragging) {
      final Offset force = (_dragTarget - _dragPosition) * kDragStiffness;
      final Offset dampingForce = _dragVelocity * kDragDamping;
      final Offset acceleration = force - dampingForce;
      _dragVelocity += acceleration * dt;
      _dragPosition += _dragVelocity * dt;

      dragSettled = (_dragPosition - _dragTarget).distance < 0.05 && _dragVelocity.distance < 0.05;
      if (dragSettled) {
        _dragPosition = _dragTarget;
        _dragVelocity = Offset.zero;
      }
    } else {
      dragSettled = false;
    }

    // 2. Scale spring physics
    final double scaleForce = (_scaleTarget - _scale) * kScaleStiffness;
    final double scaleDampingForce = _scaleVelocity * kScaleDamping;
    final double scaleAcceleration = scaleForce - scaleDampingForce;
    _scaleVelocity += scaleAcceleration * dt;
    _scale += _scaleVelocity * dt;

    scaleSettled = (_scaleTarget - _scale).abs() < 0.001 && _scaleVelocity.abs() < 0.001;
    if (scaleSettled) {
      _scale = _scaleTarget;
      _scaleVelocity = 0.0;
    }

    // If both springs have reached equilibrium, stop the ticker to save CPU/GPU cycles
    if (dragSettled && scaleSettled) {
      _ticker.stop();
      _lastElapsed = null;
    }

    setState(() {});
  }

  void _handlePointerDown(PointerDownEvent event) {
    _velocityTracker = VelocityTracker.withKind(event.kind);
    _velocityTracker.addPosition(event.timeStamp, event.position);

    setState(() {
      _isPressed = true;
      _scaleTarget = 1.25; // Scale up instantly on tap down
      _isDragging = true;
      _pointerStartGlobalPosition = event.position;
      _dragOffsetAccumulated = Offset.zero;
      _dragPosition = Offset.zero;
    });
    _startTicker();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isDragging) return;
    _velocityTracker.addPosition(event.timeStamp, event.position);

    final displacement = event.position - _pointerStartGlobalPosition;
    _dragOffsetAccumulated = displacement;

    // Apply soft rubber banding distance constraint
    final distance = displacement.distance;
    const maxDrag = 65.0;

    Offset elasticOffset;
    if (distance > 0) {
      final double rubberDistance = maxDrag * (1.0 - math.exp(-distance / maxDrag));
      elasticOffset = displacement * (rubberDistance / distance);
    } else {
      elasticOffset = Offset.zero;
    }

    setState(() {
      _dragPosition = elasticOffset;
      _dragVelocity = Offset.zero; // Force zero velocity while dragging active
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!_isDragging) return;
    _velocityTracker.addPosition(event.timeStamp, event.position);

    final velocity = _velocityTracker.getVelocity().pixelsPerSecond;
    Offset releaseVelocity = velocity;
    final speed = releaseVelocity.distance;
    const maxSpeed = 900.0;
    if (speed > maxSpeed) {
      releaseVelocity = releaseVelocity * (maxSpeed / speed);
    }

    setState(() {
      _isDragging = false;
      _isPressed = false;
      _scaleTarget = 1.0; // Return to original scale (spring physics handles the overshoot & bounce)
      _dragTarget = Offset.zero;
      _dragVelocity = releaseVelocity;
    });
    _startTicker();

    // Trigger onTap if the movement was a tap or short flick
    if (_dragOffsetAccumulated.distance < 12.0) {
      widget.onTap();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    setState(() {
      _isDragging = false;
      _isPressed = false;
      _scaleTarget = 1.0;
      _dragTarget = Offset.zero;
      _dragVelocity = Offset.zero;
    });
    _startTicker();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Dynamic deformation matrix values
    final double dragDistance = _dragPosition.distance;
    final double dragAngle = dragDistance > 0.01 ? _dragPosition.direction : 0.0;

    // Non-uniform scaling: stretches along the motion vector, squishes along the normal vector
    final double stretchFactor = math.min(dragDistance / 90.0, 0.4);
    final double scaleX = (1.0 + stretchFactor) * _scale;
    final double scaleY = (1.0 - stretchFactor * 0.45) * _scale;

    return Transform.translate(
      offset: _dragPosition,
      child: Transform.rotate(
        angle: dragAngle,
        child: Transform.scale(
          scaleX: scaleX,
          scaleY: scaleY,
          child: Transform.rotate(
            angle: -dragAngle, // Keep internal icon upright and aligned
            child: _buildButtonBody(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonBody(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = widget.themeColor ?? theme.colorScheme.primary;

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Glassmorphic Circle Button
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E2F).withValues(alpha: _isPressed ? 0.75 : 0.35)
                      : Colors.white.withValues(alpha: _isPressed ? 0.8 : 0.4),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: _isPressed ? 0.25 : 0.12),
                      blurRadius: _isPressed ? 14 : 8,
                      offset: Offset(0, _isPressed ? 6 : 3),
                    ),
                  ],
                  border: Border.all(
                    color: activeColor.withValues(alpha: _isPressed ? 0.5 : 0.18),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.chevron_down,
                    color: activeColor.withValues(alpha: _isPressed ? 1.0 : 0.7),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          // Floating Unread Message Indicator Badge
          if (widget.unreadCount > 0)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: _isPressed ? 1.0 : 0.9),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Center(
                  child: Text(
                    widget.unreadCount > 99 ? '99+' : '${widget.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
