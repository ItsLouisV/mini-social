import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/chat_link_utils.dart';

class ExpandableMessageText extends StatefulWidget {
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

  @override
  State<ExpandableMessageText> createState() => _ExpandableMessageTextState();
}

class _ExpandableMessageTextState extends State<ExpandableMessageText> {
  final Map<String, TapGestureRecognizer> _linkRecognizers = {};

  TextSpan _buildSpan(BuildContext context) {
    final mentionColor = Theme.of(context).colorScheme.primary;
    final children = <InlineSpan>[];
    var cursor = 0;
    final links = ChatLinkUtils.findLinks(widget.text);
    final parts = <({int start, int end, String text, bool isLink})>[
      for (final link in links)
        (start: link.start, end: link.end, text: link.text, isLink: true),
      for (final mention in RegExp(r'@[^\s.,!?;:()]+').allMatches(widget.text))
        if (!links.any((link) =>
            mention.start >= link.start && mention.start < link.end))
          (
            start: mention.start,
            end: mention.end,
            text: mention.group(0)!,
            isLink: false,
          ),
    ]..sort((a, b) => a.start.compareTo(b.start));

    for (final part in parts) {
      if (part.start < cursor) continue;
      if (part.start > cursor) {
        children.add(TextSpan(text: widget.text.substring(cursor, part.start)));
      }

      if (part.isLink) {
        final link = links.firstWhere((item) => item.start == part.start);
        final recognizer = _linkRecognizers.putIfAbsent(
          link.url,
          () => TapGestureRecognizer()..onTap = () => _openLink(link.url),
        );
        children.add(TextSpan(
          text: part.text,
          style: widget.style.copyWith(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
          recognizer: recognizer,
        ));
      } else {
        children.add(TextSpan(
          text: part.text,
          style: widget.style.copyWith(
            color: mentionColor,
            fontWeight: FontWeight.w700,
          ),
        ));
      }
      cursor = part.end;
    }

    if (cursor < widget.text.length) {
      children.add(TextSpan(text: widget.text.substring(cursor)));
    }
    return TextSpan(style: widget.style, children: children);
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final recognizer in _linkRecognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = _buildSpan(context);
        final painter = TextPainter(
          text: textSpan,
          maxLines: widget.collapsedLines,
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
                maxLines: widget.expanded ? null : widget.collapsedLines,
                overflow: widget.expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
              if (isOverflowing || widget.expanded) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onToggle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        widget.expanded ? 'Thu gọn' : 'Xem thêm',
                        textAlign: TextAlign.right,
                        style: widget.style.copyWith(
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
