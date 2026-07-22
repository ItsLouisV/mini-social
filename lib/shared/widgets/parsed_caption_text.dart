import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

class ParsedCaptionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  const ParsedCaptionText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  static final RegExp _tagOrMentionRegExp = RegExp(
    r'(#[\w_]+|@[\w_\.]+)',
    unicode: true,
  );

  @override
  Widget build(BuildContext context) {
    final defaultStyle = style ??
        TextStyle(
          fontSize: 14,
          height: 1.3,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        );

    final highlightStyle = defaultStyle.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
    );

    final spans = <TextSpan>[];
    int start = 0;

    for (final match in _tagOrMentionRegExp.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: defaultStyle,
        ));
      }

      final matchText = match.group(0)!;
      final isHashtag = matchText.startsWith('#');

      spans.add(
        TextSpan(
          text: matchText,
          style: highlightStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              if (isHashtag) {
                final tag = matchText.substring(1);
                context.push('/search?q=%23$tag');
              } else {
                final username = matchText.substring(1);
                context.push('/search?q=$username');
              }
            },
        ),
      );

      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: defaultStyle,
      ));
    }

    return RichText(
      maxLines: maxLines,
      overflow: overflow,
      text: TextSpan(children: spans),
    );
  }
}
