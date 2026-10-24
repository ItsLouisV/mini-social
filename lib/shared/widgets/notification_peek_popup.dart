import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mô tả chi tiết một hành động trong menu peek (giống iOS context menu).
class NotificationPeekAction {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  final bool isDestructive;

  const NotificationPeekAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.isDestructive = false,
  });
}

/// Widget bọc ngoài bất kỳ widget nào để thêm long-press peek popup kiểu iOS.
///
/// Cách dùng:
/// ```dart
/// NotificationPeekWrapper(
///   peekCard: MyDetailCard(notification: n),
///   actions: [
///     NotificationPeekAction(icon: CupertinoIcons.trash, label: 'Xóa', isDestructive: true, onTap: () {}),
///   ],
///   child: MyListTile(notification: n),
/// )
/// ```
class NotificationPeekWrapper extends StatefulWidget {
  /// Widget con hiển thị bình thường trong danh sách.
  final Widget child;

  /// Widget hiển thị bên trong popup khi nhấn giữ.
  final Widget peekCard;

  /// Các action hiện dưới popup (tùy chọn).
  final List<NotificationPeekAction> actions;

  const NotificationPeekWrapper({
    super.key,
    required this.child,
    required this.peekCard,
    this.actions = const [],
  });

  @override
  State<NotificationPeekWrapper> createState() => _NotificationPeekWrapperState();
}

class _NotificationPeekWrapperState extends State<NotificationPeekWrapper> {
  void _showPeek(BuildContext context) {
    HapticFeedback.mediumImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        return _NotificationPeekOverlay(
          animation: anim,
          peekCard: widget.peekCard,
          actions: widget.actions,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showPeek(context),
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// Overlay nội bộ
// ---------------------------------------------------------------------------

class _NotificationPeekOverlay extends StatelessWidget {
  final Animation<double> animation;
  final Widget peekCard;
  final List<NotificationPeekAction> actions;

  const _NotificationPeekOverlay({
    required this.animation,
    required this.peekCard,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Scale + fade animation
    final scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
    );
    final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOut),
    );

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
        fit: StackFit.expand,
        children: [
          // Blur backdrop
          AnimatedBuilder(
            animation: animation,
            builder: (_, __) {
              return BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 12 * animation.value,
                  sigmaY: 12 * animation.value,
                ),
                child: Container(
                  color: (isDark ? Colors.black : Colors.black)
                      .withValues(alpha: 0.35 * animation.value),
                ),
              );
            },
          ),

          // Centered content
          Center(
            child: GestureDetector(
              // Chặn tap vào card đóng overlay
              onTap: () {},
              child: AnimatedBuilder(
                animation: animation,
                builder: (_, child) => FadeTransition(
                  opacity: opacity,
                  child: ScaleTransition(
                    scale: scale,
                    child: child,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Peek card ──────────────────────────────────────
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E1E2F).withValues(alpha: 0.92)
                                  : Colors.white.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.10)
                                    : Colors.black.withValues(alpha: 0.06),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  blurRadius: 40,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: peekCard,
                          ),
                        ),
                      ),

                      // ── Action menu ────────────────────────────────────
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E1E2F).withValues(alpha: 0.92)
                                    : Colors.white.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.05),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.20),
                                    blurRadius: 24,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: _buildActionItems(context, isDark),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),  // GestureDetector
    ); // Material
  }

  List<Widget> _buildActionItems(BuildContext context, bool isDark) {
    final items = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      final action = actions[i];
      final color = action.isDestructive
          ? Colors.redAccent
          : (action.color ?? Theme.of(context).textTheme.bodyLarge?.color);

      items.add(
        InkWell(
          onTap: () {
            Navigator.of(context).pop();
            action.onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(action.icon, color: color, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    action.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (i < actions.length - 1) {
        items.add(
          Divider(
            height: 1,
            thickness: 0.5,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.07),
            indent: 20,
          ),
        );
      }
    }
    return items;
  }
}
