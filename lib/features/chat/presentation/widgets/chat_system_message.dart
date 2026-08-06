import 'package:flutter/material.dart';

class SystemMessageDivider extends StatelessWidget {
  final String text;
  final VoidCallback? onChangeTap;

  const SystemMessageDivider({
    super.key,
    required this.text,
    this.onChangeTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.hintColor,
                  height: 1.3,
                ),
              ),
              if (onChangeTap != null) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onChangeTap,
                  child: const Text(
                    'Thay đổi',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.purpleAccent,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.purpleAccent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DateHeaderDivider extends StatelessWidget {
  final DateTime dateTime;

  const DateHeaderDivider({
    super.key,
    required this.dateTime,
  });

  String _format() {
    final local = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sixDaysAgo = today.subtract(const Duration(days: 6));
    final dateOnly = DateTime(local.year, local.month, local.day);
    final hhmm = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    if (dateOnly == today) return hhmm;
    if (dateOnly == yesterday) return 'Hôm qua, $hhmm';
    if (dateOnly.isAfter(sixDaysAgo)) {
      const days = [
        'Chủ Nhật',
        'Thứ Hai',
        'Thứ Ba',
        'Thứ Tư',
        'Thứ Năm',
        'Thứ Sáu',
        'Thứ Bảy'
      ];
      final idx = local.weekday == 7 ? 0 : local.weekday;
      return '${days[idx]}, $hhmm';
    }
    final d = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    return '$d/$mo/${local.year}, $hhmm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _format(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: theme.hintColor,
            ),
          ),
        ),
      ),
    );
  }
}
