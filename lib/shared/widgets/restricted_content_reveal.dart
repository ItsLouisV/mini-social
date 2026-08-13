import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const restrictedContentNotice =
    'Các bài viết đã bị ẩn do có thể mang tính xúc phạm, vi phạm tiêu chuẩn.';

class RestrictedContentReveal extends StatelessWidget {
  const RestrictedContentReveal({
    super.key,
    required this.actionLabel,
    required this.onReveal,
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  final String actionLabel;
  final VoidCallback onReveal;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.eye,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restrictedContentNotice,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: onReveal,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(CupertinoIcons.eye, size: 17),
                  label: Text(actionLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
