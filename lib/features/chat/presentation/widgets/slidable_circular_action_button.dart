import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// Data model cho từng nút hành động hình tròn
class SlidableActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const SlidableActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

/// Coordinates custom swipe tiles so opening one closes the previously open
/// tile in the same list.
class IOSSlidableAutoCloseBehavior extends StatefulWidget {
  final Widget child;

  const IOSSlidableAutoCloseBehavior({super.key, required this.child});

  @override
  State<IOSSlidableAutoCloseBehavior> createState() =>
      _IOSSlidableAutoCloseBehaviorState();
}

class _IOSSlidableAutoCloseBehaviorState
    extends State<IOSSlidableAutoCloseBehavior> {
  _IOSRubberbandSlidableTileState? _activeTile;

  void claim(_IOSRubberbandSlidableTileState tile) {
    if (!identical(_activeTile, tile)) {
      _activeTile?.close();
      _activeTile = tile;
    }
  }

  void release(_IOSRubberbandSlidableTileState tile) {
    if (identical(_activeTile, tile)) _activeTile = null;
  }

  @override
  Widget build(BuildContext context) => _IOSSlidableScope(
        state: this,
        child: widget.child,
      );
}

class _IOSSlidableScope extends InheritedWidget {
  final _IOSSlidableAutoCloseBehaviorState state;

  const _IOSSlidableScope({required this.state, required super.child});

  static _IOSSlidableAutoCloseBehaviorState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_IOSSlidableScope>()?.state;

  @override
  bool updateShouldNotify(_IOSSlidableScope oldWidget) => false;
}

/// Widget vuốt (swipe) mượt chuẩn iOS:
/// - Kéo thả tự do không bị giới hạn cứng (Over-drag Rubberband physics)
/// - Khi thả tay, tự động nảy đàn hồi (Spring Rebound) về dừng ở mép nút action cuối cùng
class IOSRubberbandSlidableTile extends StatefulWidget {
  final Widget child;
  final List<SlidableActionItem>? startActions;
  final List<SlidableActionItem>? endActions;
  final double actionSlotWidth;

  const IOSRubberbandSlidableTile({
    super.key,
    required this.child,
    this.startActions,
    this.endActions,
    this.actionSlotWidth = 72.0,
  });

  @override
  State<IOSRubberbandSlidableTile> createState() =>
      _IOSRubberbandSlidableTileState();
}

class _IOSRubberbandSlidableTileState extends State<IOSRubberbandSlidableTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragOffset = 0.0;
  _IOSSlidableAutoCloseBehaviorState? _autoCloseGroup;

  double get _startMaxW =>
      (widget.startActions?.length ?? 0) * widget.actionSlotWidth;
  double get _endMaxW =>
      (widget.endActions?.length ?? 0) * widget.actionSlotWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this);
    _controller.addListener(() {
      setState(() {
        _dragOffset = _controller.value;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextGroup = _IOSSlidableScope.maybeOf(context);
    if (!identical(_autoCloseGroup, nextGroup)) {
      _autoCloseGroup?.release(this);
      _autoCloseGroup = nextGroup;
    }
  }

  @override
  void dispose() {
    _autoCloseGroup?.release(this);
    _controller.dispose();
    super.dispose();
  }

  void close() {
    _animateTo(0.0, 0.0);
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _controller.stop();
    _autoCloseGroup?.claim(this);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    _controller.stop();
    double newOffset = _dragOffset + details.primaryDelta!;

    // Vuốt sang phải (hiển thị startActions)
    if (newOffset > 0) {
      if (_startMaxW == 0) {
        newOffset = 0;
      } else if (newOffset > _startMaxW) {
        // Ma sát đàn hồi Rubberband chuẩn iOS khi vuốt quá giới hạn
        final over = newOffset - _startMaxW;
        newOffset = _startMaxW + (1 - 1 / (over * 0.012 + 1)) * 50;
      }
    }
    // Vuốt sang trái (hiển thị endActions)
    else if (newOffset < 0) {
      if (_endMaxW == 0) {
        newOffset = 0;
      } else if (newOffset.abs() > _endMaxW) {
        // Ma sát đàn hồi Rubberband chuẩn iOS khi vuốt quá giới hạn
        final over = newOffset.abs() - _endMaxW;
        newOffset = -(_endMaxW + (1 - 1 / (over * 0.012 + 1)) * 50);
      }
    }

    _controller.value = newOffset;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    double targetOffset = 0.0;

    if (_dragOffset > 0 && _startMaxW > 0) {
      if (velocity > 250 || _dragOffset > _startMaxW * 0.4) {
        targetOffset = _startMaxW;
      } else {
        targetOffset = 0.0;
      }
    } else if (_dragOffset < 0 && _endMaxW > 0) {
      if (velocity < -250 || _dragOffset.abs() > _endMaxW * 0.4) {
        targetOffset = -_endMaxW;
      } else {
        targetOffset = 0.0;
      }
    }

    _animateTo(targetOffset, velocity);
  }

  void _animateTo(double target, double velocity) {
    final spring = SpringDescription(
      mass: 1.0,
      stiffness: 380,
      damping: 24,
    );
    final simulation = SpringSimulation(
      spring,
      _dragOffset,
      target,
      velocity,
    );
    _controller.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    final offset = _dragOffset;
    final isRight = offset > 0;
    final isLeft = offset < 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Các nút hành động nằm bên dưới (Behind Motion)
        Positioned.fill(
          child: Container(
            color: Colors.transparent,
            child: Row(
              children: [
                if (isRight &&
                    widget.startActions != null &&
                    widget.startActions!.isNotEmpty)
                  SizedBox(
                    width: _startMaxW,
                    child: _buildActionRow(
                      actions: widget.startActions!,
                      progress: (offset / _startMaxW).clamp(0.0, 2.0),
                      isStart: true,
                    ),
                  ),
                const Spacer(),
                if (isLeft &&
                    widget.endActions != null &&
                    widget.endActions!.isNotEmpty)
                  SizedBox(
                    width: _endMaxW,
                    child: _buildActionRow(
                      actions: widget.endActions!,
                      progress: (-offset / _endMaxW).clamp(0.0, 2.0),
                      isStart: false,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Thẻ hội thoại kéo di chuyển
        Transform.translate(
          offset: Offset(offset, 0),
          child: GestureDetector(
            onHorizontalDragStart: _onHorizontalDragStart,
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow({
    required List<SlidableActionItem> actions,
    required double progress,
    required bool isStart,
  }) {
    final count = actions.length;

    return Row(
      children: List.generate(count, (index) {
        final item = actions[index];
        // Swiping left (!isStart): index 1 (Xóa) gets revealIndex = 0 (blooms first), index 0 (Ẩn) gets revealIndex = 1 (blooms second)
        final revealIndex = isStart ? index : (count - 1 - index);

        // Calculate normalized progress threshold per button
        final double startThreshold = count == 1 ? 0.0 : (revealIndex * 0.30);
        final double endThreshold = (startThreshold + 0.60).clamp(0.0, 1.0);

        final double buttonProgress = progress <= startThreshold
            ? 0.0
            : ((progress - startThreshold) / (endThreshold - startThreshold))
                .clamp(0.0, 1.0);

        if (buttonProgress <= 0.0) {
          return const Expanded(child: SizedBox.shrink());
        }

        final double curvedVal = Curves.easeOutCubic.transform(buttonProgress);
        final double scale = (curvedVal).clamp(0.0, 1.08);
        final double circleOpacity =
            Curves.easeOut.transform(buttonProgress.clamp(0.0, 1.0));
        final double labelOpacity = buttonProgress > 0.25
            ? Curves.easeOut
                .transform(((buttonProgress - 0.25) / 0.75).clamp(0.0, 1.0))
            : 0.0;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              close();
              item.onTap();
            },
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: circleOpacity,
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.center,
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item.icon, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Opacity(
                    opacity: labelOpacity,
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        color: Color(0xFF98989F),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.2,
                        height: 1.05,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
