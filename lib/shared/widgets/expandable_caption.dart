import 'package:flutter/material.dart';

/// Widget [ExpandableCaption] hiển thị nội dung bài viết dạng có thể thu gọn / mở rộng
/// tương tự giao diện của Facebook, Instagram, Threads.
///
/// **Đặc điểm kỹ thuật**:
/// - Đo đạc độ tràn chính xác bằng [TextPainter.didExceedMaxLines], KHÔNG đếm `text.length`.
/// - Tối ưu hiệu năng: Cache kết quả đo [TextPainter], chỉ đo lại khi các thuộc tính thay đổi (text, width, style, collapsedLines, textScaler).
/// - Hỗ trợ Emoji, Tiếng Việt/Anh/Trung, RTL, RichText (#hashtag, @mention), và Dynamic Text Scaling (Accessibility).
/// - Chuyển đổi trạng thái mượt mà bằng [AnimatedSize] không gây giật lag (flicker).
class ExpandableCaption extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int collapsedLines;
  final ValueChanged<bool>? onExpandChanged;
  final String expandText;
  final String collapseText;
  final TextStyle? buttonStyle;
  final Duration animationDuration;
  final Curve animationCurve;
  final InlineSpan Function(String text, TextStyle effectiveStyle)? textSpanBuilder;

  const ExpandableCaption({
    super.key,
    required this.text,
    this.style,
    this.collapsedLines = 3,
    this.onExpandChanged,
    this.expandText = 'Xem thêm',
    this.collapseText = 'Thu gọn',
    this.buttonStyle,
    this.animationDuration = const Duration(milliseconds: 250),
    this.animationCurve = Curves.fastOutSlowIn,
    this.textSpanBuilder,
  });

  @override
  State<ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<ExpandableCaption> {
  bool _isExpanded = false;

  // Cache variables để tránh đo đạc TextPainter liên tục mỗi lần rebuild
  String? _cachedText;
  TextStyle? _cachedStyle;
  int? _cachedCollapsedLines;
  double? _cachedMaxWidth;
  TextScaler? _cachedTextScaler;
  TextDirection? _cachedTextDirection;
  bool _isOverflowing = false;

  /// Hàm đo đạc xem văn bản có bị vượt quá [collapsedLines] hay không
  void _calculateOverflow(
    double maxWidth,
    TextScaler textScaler,
    TextDirection textDirection,
    TextStyle effectiveStyle,
  ) {
    // Kiểm tra xem có cần phải đo lại hay không (Cache Hit)
    if (_cachedText == widget.text &&
        _cachedStyle == effectiveStyle &&
        _cachedCollapsedLines == widget.collapsedLines &&
        _cachedMaxWidth == maxWidth &&
        _cachedTextScaler == textScaler &&
        _cachedTextDirection == textDirection) {
      return; // Cache còn hiệu lực -> Dùng lại kết quả cũ
    }

    // Nếu văn bản rỗng -> chắc chắn không tràn
    if (widget.text.isEmpty) {
      _isOverflowing = false;
      _updateCache(maxWidth, textScaler, textDirection, effectiveStyle);
      return;
    }

    // Dùng TextPainter để render thử văn bản ngầm trong bộ nhớ
    final spanToMeasure = widget.textSpanBuilder != null
        ? widget.textSpanBuilder!(widget.text, effectiveStyle)
        : TextSpan(text: widget.text, style: effectiveStyle);

    final textPainter = TextPainter(
      text: spanToMeasure,
      maxLines: widget.collapsedLines,
      textDirection: textDirection,
      textScaler: textScaler,
    );

    // Layout với chiều rộng thực tế của ô chứa
    textPainter.layout(maxWidth: maxWidth);

    // Kiểm tra cờ didExceedMaxLines do Flutter Engine tính toán
    _isOverflowing = textPainter.didExceedMaxLines;

    // Giải phóng bộ nhớ của TextPainter
    textPainter.dispose();

    // Cập nhật bộ nhớ đệm (Cache)
    _updateCache(maxWidth, textScaler, textDirection, effectiveStyle);
  }

  void _updateCache(
    double maxWidth,
    TextScaler textScaler,
    TextDirection textDirection,
    TextStyle effectiveStyle,
  ) {
    _cachedText = widget.text;
    _cachedStyle = effectiveStyle;
    _cachedCollapsedLines = widget.collapsedLines;
    _cachedMaxWidth = maxWidth;
    _cachedTextScaler = textScaler;
    _cachedTextDirection = textDirection;
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onExpandChanged?.call(_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveStyle = defaultStyle.merge(widget.style);
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    final defaultBtnStyle = TextStyle(
      color: const Color(0xFF8A8D91),
      fontWeight: FontWeight.bold,
      fontSize: (effectiveStyle.fontSize ?? 14.0) * 0.95,
    );
    final effectiveBtnStyle = defaultBtnStyle.merge(widget.buttonStyle);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;

        // Tiến hành đo đạc độ tràn (chỉ tính toán lại nếu có sự thay đổi kích thước/thuộc tính)
        _calculateOverflow(maxWidth, textScaler, textDirection, effectiveStyle);

        final spanToRender = widget.textSpanBuilder != null
            ? widget.textSpanBuilder!(widget.text, effectiveStyle)
            : TextSpan(text: widget.text, style: effectiveStyle);

        return AnimatedSize(
          duration: widget.animationDuration,
          curve: widget.animationCurve,
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: spanToRender,
                maxLines: _isExpanded ? null : widget.collapsedLines,
                overflow: _isExpanded ? TextOverflow.clip : TextOverflow.ellipsis,
                textScaler: textScaler,
                textDirection: textDirection,
              ),
              if (_isOverflowing) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _toggleExpanded,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      _isExpanded ? widget.collapseText : '... ${widget.expandText}',
                      style: effectiveBtnStyle,
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
