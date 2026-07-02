import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MessagePopupMenuContent extends StatelessWidget {
  final bool isMine;
  final bool isPinned;
  final bool isText;
  final VoidCallback onReply;
  final VoidCallback onPin;
  final VoidCallback onUnpin;
  final VoidCallback onCopy;
  final VoidCallback onForward;
  final VoidCallback? onRecall; // Only applicable if isMine is true
  final VoidCallback onDelete;
  final VoidCallback onInfo;
  final Function(String emoji) onReact;
  final bool hasMyReaction;
  final VoidCallback? onClearAllReactions;

  const MessagePopupMenuContent({
    super.key,
    required this.isMine,
    required this.isPinned,
    required this.isText,
    required this.onReply,
    required this.onPin,
    required this.onUnpin,
    required this.onCopy,
    required this.onForward,
    this.onRecall,
    required this.onDelete,
    required this.onInfo,
    required this.onReact,
    this.hasMyReaction = false,
    this.onClearAllReactions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final containerColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;

    // Build the grid items
    final List<_GridActionItem> actionItems = [
      _GridActionItem(
        icon: CupertinoIcons.reply,
        label: 'Trả lời',
        onTap: onReply,
        iconColor: Colors.blue,
      ),
      _GridActionItem(
        icon: CupertinoIcons.arrowshape_turn_up_right,
        label: 'Chuyển tiếp',
        onTap: onForward,
        iconColor: Colors.green,
      ),
      if (isText)
        _GridActionItem(
          icon: CupertinoIcons.doc_on_doc,
          label: 'Sao chép',
          onTap: onCopy,
          iconColor: Colors.teal,
        ),
      _GridActionItem(
        icon: isPinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
        label: isPinned ? 'Bỏ ghim' : 'Ghim',
        onTap: isPinned ? onUnpin : onPin,
        iconColor: Colors.amber[700]!,
      ),
      if (isMine && onRecall != null)
        _GridActionItem(
          icon: CupertinoIcons.arrow_counterclockwise,
          label: 'Thu hồi',
          onTap: onRecall!,
          iconColor: Colors.deepOrange,
        ),
      _GridActionItem(
        icon: CupertinoIcons.info,
        label: 'Chi tiết',
        onTap: onInfo,
        iconColor: Colors.indigo,
      ),
      _GridActionItem(
        icon: CupertinoIcons.trash,
        label: 'Xóa',
        onTap: onDelete,
        iconColor: Colors.red,
        isDestructive: true,
      ),
    ];

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Emoji Reaction Bar (Horizontal list of emojis)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                  return _EmojiItem(
                    emoji: emoji,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onReact(emoji);
                    },
                  );
                }),
                if (hasMyReaction)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        onClearAllReactions?.call();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.red.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.heart_slash,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Zalo-style Actions Grid
          Container(
            width: 290,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 14,
              alignment: WrapAlignment.start,
              children: actionItems.map((item) {
                return SizedBox(
                  width: 60,
                  child: GestureDetector(
                    onTap: item.onTap,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Circular Icon Wrapper
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: item.isDestructive
                                ? Colors.red.withValues(alpha: 0.1)
                                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item.icon,
                            size: 20,
                            color: item.iconColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Label text below
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final bool isDestructive;

  const _GridActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.iconColor,
    this.isDestructive = false,
  });
}

class _EmojiItem extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _EmojiItem({
    required this.emoji,
    required this.onTap,
  });

  @override
  State<_EmojiItem> createState() => _EmojiItemState();
}

class _EmojiItemState extends State<_EmojiItem> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: MouseRegion(
        onEnter: (_) => _controller.forward(),
        onExit: (_) => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
            child: Text(
              widget.emoji,
              style: const TextStyle(
                fontSize: 24,
                fontFamilyFallback: ['Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji'],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
