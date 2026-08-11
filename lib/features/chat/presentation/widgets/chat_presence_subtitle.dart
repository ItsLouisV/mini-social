import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/chat_provider.dart';

class ChatPresenceSubtitle extends ConsumerWidget {
  final bool isGroup;
  final int memberCount;
  final String? userId;

  const ChatPresenceSubtitle({
    super.key,
    required this.isGroup,
    this.memberCount = 0,
    this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.62);

    if (isGroup) {
      return Text(
        '$memberCount thành viên',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: mutedColor),
      );
    }

    final id = userId;
    if (id == null || id.isEmpty) return const SizedBox.shrink();

    final presence = ref.watch(userPresenceProvider(id));
    return presence.when(
      loading: () => const SizedBox(height: 14),
      error: (_, __) => const SizedBox.shrink(),
      data: (value) {
        final isOnline = value.isOnline;
        final label = isOnline
            ? 'Đang hoạt động'
            : _formatLastActive(value.lastActive, DateTime.now());
        if (label == null) return const SizedBox.shrink();

        final color = isOnline ? Colors.green : mutedColor;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOnline) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: isOnline ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String? _formatLastActive(DateTime? lastActive, DateTime now) {
    if (lastActive == null) return null;

    final difference = now.difference(lastActive);
    if (difference.isNegative || difference.inMinutes < 1) {
      return 'Hoạt động 1 phút trước';
    }
    if (difference.inMinutes < 60) {
      return 'Hoạt động ${difference.inMinutes} phút trước';
    }
    if (difference.inHours < 24) {
      return 'Hoạt động ${difference.inHours} giờ trước';
    }

    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return 'Hoạt động lần cuối ${twoDigits(lastActive.day)}/'
        '${twoDigits(lastActive.month)}/${lastActive.year}';
  }
}
