import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../features/social/data/ai_repository.dart';

class ParsedCaptionText extends ConsumerStatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  final bool enableTranslate;

  const ParsedCaptionText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.enableTranslate = true,
  });

  @override
  ConsumerState<ParsedCaptionText> createState() => _ParsedCaptionTextState();
}

class _ParsedCaptionTextState extends ConsumerState<ParsedCaptionText> {
  bool _isTranslating = false;
  String? _translatedText;
  bool _showTranslation = false;

  static final RegExp _tagOrMentionRegExp = RegExp(
    r'(#[\w_]+|@[\w_\.]+)',
    unicode: true,
  );

  Future<void> _handleTranslate() async {
    if (_translatedText != null) {
      setState(() => _showTranslation = !_showTranslation);
      return;
    }

    setState(() => _isTranslating = true);
    try {
      final res = await ref.read(aiRepositoryProvider).translateText(widget.text);
      if (mounted) {
        setState(() {
          _translatedText = res;
          _showTranslation = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayText = (_showTranslation && _translatedText != null)
        ? _translatedText!
        : widget.text;

    final defaultStyle = widget.style ??
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

    for (final match in _tagOrMentionRegExp.allMatches(displayText)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: displayText.substring(start, match.start),
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

    if (start < displayText.length) {
      spans.add(TextSpan(
        text: displayText.substring(start),
        style: defaultStyle,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          maxLines: widget.maxLines,
          overflow: widget.overflow,
          text: TextSpan(children: spans),
        ),
        if (widget.enableTranslate && widget.text.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          InkWell(
            onTap: _isTranslating ? null : _handleTranslate,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.g_translate_outlined,
                    size: 13,
                    color: Theme.of(context).hintColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isTranslating
                        ? 'Đang dịch...'
                        : (_showTranslation ? 'Xem bản gốc' : 'Xem bản dịch'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
