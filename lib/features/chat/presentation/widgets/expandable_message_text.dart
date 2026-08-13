import 'package:flutter/material.dart';

class ExpandableMessageText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final bool expanded;
  final VoidCallback onToggle;
  final int collapsedLines;

  const ExpandableMessageText({
    super.key,
    required this.text,
    required this.style,
    required this.expanded,
    required this.onToggle,
    this.collapsedLines = 12,
  });

  TextSpan _buildSpan(BuildContext context) {
    final mentionColor = Theme.of(context).colorScheme.primary;
    final children = <InlineSpan>[];
    var cursor = 0;

    for (final match in RegExp(r'@[^\s.,!?;:()]+').allMatches(text)) {
      if (match.start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      children.add(
        TextSpan(
          text: match.group(0),
          style: style.copyWith(
            color: mentionColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      cursor = match.end;
    }

    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: style, children: children);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = _buildSpan(context);
        final painter = TextPainter(
          text: textSpan,
          maxLines: collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final isOverflowing = painter.didExceedMaxLines;
        painter.dispose();

        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                textSpan,
                maxLines: expanded ? null : collapsedLines,
                overflow:
                    expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
              if (isOverflowing || expanded) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        expanded ? 'Thu gọn' : 'Xem thêm',
                        textAlign: TextAlign.right,
                        style: style.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
