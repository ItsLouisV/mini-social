import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Vị trí hiển thị Toast trên màn hình
enum ToastPosition { top, bottom, center }

/// Loại thông báo Toast
enum ToastType { success, error, warning, info, custom }

/// Service quản lý Toast thông báo toàn ứng dụng sử dụng Flutter OverlayEntry với hiệu ứng Apple Dynamic Island
class ToastService {
  ToastService._();

  static OverlayEntry? _currentEntry;
  static GlobalKey<_ToastOverlayWidgetState>? _currentKey;

  /// Hiển thị Toast với phong cách Apple Dynamic Island (Phóng to khi vào & Thu nhỏ khi ẩn)
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    ToastType type = ToastType.info,
    ToastPosition position = ToastPosition.top,
    Duration duration = const Duration(milliseconds: 2800),
    IconData? customIcon,
    Color? customColor,
    double borderRadius = 24.0,
    double blurSigma = 18.0,
    VoidCallback? onTap,
    bool enableSwipeToDismiss = true,
  }) {
    // Ẩn Toast cũ ngay lập tức nếu đang hiển thị
    dismissImmediately();

    final overlayState = Overlay.of(context, rootOverlay: true);
    final key = GlobalKey<_ToastOverlayWidgetState>();
    _currentKey = key;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ToastOverlayWidget(
        key: key,
        message: message,
        title: title,
        type: type,
        position: position,
        duration: duration,
        customIcon: customIcon,
        customColor: customColor,
        borderRadius: borderRadius,
        blurSigma: blurSigma,
        onTap: onTap,
        enableSwipeToDismiss: enableSwipeToDismiss,
        onRemoveEntry: () {
          if (_currentEntry == entry) {
            entry.remove();
            _currentEntry = null;
            _currentKey = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlayState.insert(entry);
  }

  /// Tắt Toast hiện tại với hiệu ứng thu nhỏ Apple
  static void dismiss() {
    if (_currentKey?.currentState != null) {
      _currentKey!.currentState!.dismissWithAnimation();
    } else {
      dismissImmediately();
    }
  }

  /// Xóa ngay lập tức không cần animation
  static void dismissImmediately() {
    if (_currentEntry != null) {
      _currentEntry?.remove();
      _currentEntry = null;
      _currentKey = null;
    }
  }

  // ── 🚀 Các hàm Helper tiện lợi cho toàn bộ App ──────────────────────────────

  /// Toast thành công (Màu xanh lá)
  static void showSuccess(
    BuildContext context,
    String message, {
    String? title = 'Thành công',
    ToastPosition position = ToastPosition.top,
    Duration duration = const Duration(milliseconds: 2800),
    VoidCallback? onTap,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: ToastType.success,
      position: position,
      duration: duration,
      onTap: onTap,
    );
  }

  /// Toast thất bại / lỗi (Màu đỏ/hồng)
  static void showError(
    BuildContext context,
    String message, {
    String? title = 'Đã có lỗi xảy ra',
    ToastPosition position = ToastPosition.top,
    Duration duration = const Duration(milliseconds: 3200),
    VoidCallback? onTap,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: ToastType.error,
      position: position,
      duration: duration,
      onTap: onTap,
    );
  }

  /// Toast cảnh báo (Màu cam/vàng)
  static void showWarning(
    BuildContext context,
    String message, {
    String? title = 'Cảnh báo',
    ToastPosition position = ToastPosition.top,
    Duration duration = const Duration(milliseconds: 3000),
    VoidCallback? onTap,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: ToastType.warning,
      position: position,
      duration: duration,
      onTap: onTap,
    );
  }

  /// Toast thông tin (Màu xanh dương)
  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    ToastPosition position = ToastPosition.top,
    Duration duration = const Duration(milliseconds: 2800),
    VoidCallback? onTap,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: ToastType.info,
      position: position,
      duration: duration,
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stateful Widget điều khiển Animation Apple Dynamic Island (Scale & Slide & Blur)
// ─────────────────────────────────────────────────────────────────────────────
class _ToastOverlayWidget extends StatefulWidget {
  final String message;
  final String? title;
  final ToastType type;
  final ToastPosition position;
  final Duration duration;
  final IconData? customIcon;
  final Color? customColor;
  final double borderRadius;
  final double blurSigma;
  final VoidCallback? onTap;
  final bool enableSwipeToDismiss;
  final VoidCallback onRemoveEntry;

  const _ToastOverlayWidget({
    super.key,
    required this.message,
    required this.type,
    required this.position,
    required this.duration,
    required this.borderRadius,
    required this.blurSigma,
    required this.onRemoveEntry,
    this.title,
    this.customIcon,
    this.customColor,
    this.onTap,
    this.enableSwipeToDismiss = true,
  });

  @override
  State<_ToastOverlayWidget> createState() => _ToastOverlayWidgetState();
}

class _ToastOverlayWidgetState extends State<_ToastOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _timer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      reverseDuration: const Duration(milliseconds: 320),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      reverseCurve: const Interval(0.2, 1.0, curve: Curves.easeIn),
    );

    // Hiệu ứng Apple Dynamic Island: Phóng từ viên nhộng rảnh đỉnh (0.2) từ top trượt ra banner (1.0)
    _scaleAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack, // Phóng to bung nảy kiểu iOS
        reverseCurve: Curves.easeInBack, // Thu nhỏ thu gọn lại kiểu iOS
      ),
    );

    Offset startOffset;
    switch (widget.position) {
      case ToastPosition.top:
        startOffset = const Offset(0, -1.0);
        break;
      case ToastPosition.bottom:
        startOffset = const Offset(0, 1.0);
        break;
      case ToastPosition.center:
        startOffset = const Offset(0, 0.1);
        break;
    }

    _slideAnimation = Tween<Offset>(
      begin: startOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _controller.forward();

    // Tự động kích hoạt hiệu ứng thu nhỏ ẩn đi khi hết thời gian
    _timer = Timer(widget.duration, () {
      if (mounted) dismissWithAnimation();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> dismissWithAnimation() async {
    if (_isDismissing) return;
    _isDismissing = true;
    _timer?.cancel();
    try {
      await _controller.reverse();
    } catch (_) {}
    if (mounted) {
      widget.onRemoveEntry();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);

    // Xác định icon & màu sắc theo ToastType
    IconData iconData;
    Color accentColor;

    switch (widget.type) {
      case ToastType.success:
        iconData = CupertinoIcons.checkmark_circle_fill;
        accentColor = const Color(0xFF34C759); // Green
        break;
      case ToastType.error:
        iconData = CupertinoIcons.exclamationmark_circle_fill;
        accentColor = AppColors.secondary; // Red/Pink
        break;
      case ToastType.warning:
        iconData = CupertinoIcons.exclamationmark_triangle_fill;
        accentColor = const Color(0xFFFF9F0A); // Orange
        break;
      case ToastType.info:
        iconData = CupertinoIcons.info_circle_fill;
        accentColor = AppColors.primary; // Blue
        break;
      case ToastType.custom:
        iconData = widget.customIcon ?? CupertinoIcons.bell_fill;
        accentColor = widget.customColor ?? theme.colorScheme.primary;
        break;
    }

    // Màu nền glassmorphism theo Dark/Light Mode
    final bgColor = isDark
        ? const Color(0xFF1C1C28).withValues(alpha: 0.86)
        : Colors.white.withValues(alpha: 0.90);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.10);

    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? const Color(0xFFA0A0AB) : const Color(0xFF6E6E73);

    // Alignment cho vị trí Toast
    Alignment alignment;
    EdgeInsets outerPadding;

    switch (widget.position) {
      case ToastPosition.top:
        alignment = Alignment.topCenter;
        outerPadding = EdgeInsets.only(
          top: mediaQuery.padding.top + 10,
          left: 16,
          right: 16,
        );
        break;
      case ToastPosition.bottom:
        alignment = Alignment.bottomCenter;
        outerPadding = EdgeInsets.only(
          bottom: mediaQuery.padding.bottom + 20,
          left: 16,
          right: 16,
        );
        break;
      case ToastPosition.center:
        alignment = Alignment.center;
        outerPadding = const EdgeInsets.symmetric(horizontal: 24);
        break;
    }

    Widget content = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              alignment: widget.position == ToastPosition.bottom
                  ? Alignment.bottomCenter
                  : Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          widget.onTap?.call();
          dismissWithAnimation();
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.15),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: widget.blurSigma,
                sigmaY: widget.blurSigma,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(color: borderColor, width: 0.9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon Badge tròn với ánh mờ xung quanh
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        iconData,
                        color: accentColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Tiêu đề & Nội dung
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.title != null && widget.title!.isNotEmpty) ...[
                            Text(
                              widget.title!,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            widget.message,
                            style: TextStyle(
                              color: widget.title != null ? subtitleColor : textColor,
                              fontSize: 13,
                              fontWeight: widget.title != null ? FontWeight.w400 : FontWeight.w500,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Nút x / Đóng
                    GestureDetector(
                      onTap: dismissWithAnimation,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          CupertinoIcons.xmark,
                          size: 16,
                          color: subtitleColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Kéo để vuốt tắt Toast nếu bật enableSwipeToDismiss
    if (widget.enableSwipeToDismiss) {
      content = Dismissible(
        key: UniqueKey(),
        direction: widget.position == ToastPosition.bottom
            ? DismissDirection.down
            : DismissDirection.up,
        onDismissed: (_) => widget.onRemoveEntry(),
        child: content,
      );
    }

    return SafeArea(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: outerPadding,
          child: Material(
            color: Colors.transparent,
            child: content,
          ),
        ),
      ),
    );
  }
}
