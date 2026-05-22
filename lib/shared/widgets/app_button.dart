import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';


class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final double? borderRadius;
  final double? fontSize;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
    this.borderRadius,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = textColor ?? (isOutlined ? theme.colorScheme.onSurface : theme.colorScheme.surface);
    final background = backgroundColor ?? theme.colorScheme.onSurface;
    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CupertinoActivityIndicator(color: foreground),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final button = CupertinoButton(
      onPressed: isLoading ? null : onPressed,
      minimumSize: Size.fromHeight(height ?? 50),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isOutlined ? null : background,
      borderRadius: BorderRadius.circular(borderRadius ?? 10),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
          fontSize: fontSize ?? 15,
        ),
        child: DecoratedBox(
          decoration: isOutlined
              ? BoxDecoration(
                  border: Border.all(color: foreground, width: 1),
                  borderRadius: BorderRadius.circular(borderRadius ?? 10),
                )
              : const BoxDecoration(),
          child: Padding(
            padding: isOutlined
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 1)
                : EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: button);
    }
    return SizedBox(width: double.infinity, child: button);
  }
}
