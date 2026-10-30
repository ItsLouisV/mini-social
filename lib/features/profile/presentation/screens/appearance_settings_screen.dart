import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme_provider.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_back,
              color: theme.colorScheme.primary, size: 24),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Giao diện',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Preview Cards ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
              child: Row(
                children: [
                  Expanded(
                    child: _ThemePreviewCard(
                      label: 'Sáng',
                      isLight: true,
                      isSelected: themeMode == ThemeMode.light,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setTheme(ThemeMode.light),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _ThemePreviewCard(
                      label: 'Tối',
                      isLight: false,
                      isSelected: themeMode == ThemeMode.dark,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setTheme(ThemeMode.dark),
                    ),
                  ),
                ],
              ),
            ),

            // ── Chọn chế độ ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                'CHẾ ĐỘ HIỂN THỊ',
                style: TextStyle(
                  fontSize: 12,
                  color: labelColor,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _ModeRow(
                    icon: CupertinoIcons.sun_max_fill,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Sáng',
                    subtitle: 'Luôn dùng giao diện sáng',
                    isSelected: themeMode == ThemeMode.light,
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .setTheme(ThemeMode.light),
                  ),
                  Divider(
                    height: 0.5,
                    thickness: 0.5,
                    indent: 54,
                    color: theme.dividerColor.withValues(alpha: 0.4),
                  ),
                  _ModeRow(
                    icon: CupertinoIcons.moon_fill,
                    iconColor: const Color(0xFF6366F1),
                    title: 'Tối',
                    subtitle: 'Luôn dùng giao diện tối',
                    isSelected: themeMode == ThemeMode.dark,
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .setTheme(ThemeMode.dark),
                  ),
                  Divider(
                    height: 0.5,
                    thickness: 0.5,
                    indent: 54,
                    color: theme.dividerColor.withValues(alpha: 0.4),
                  ),
                  _ModeRow(
                    icon: CupertinoIcons.device_phone_portrait,
                    iconColor: const Color(0xFF10B981),
                    title: 'Hệ thống',
                    subtitle: 'Theo cài đặt thiết bị của bạn',
                    isSelected: themeMode == ThemeMode.system,
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .setTheme(ThemeMode.system),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Chế độ "Hệ thống" sẽ tự động chuyển giữa sáng và tối theo cài đặt màn hình của thiết bị.',
                style: TextStyle(
                  fontSize: 13,
                  color: labelColor,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Preview Card — hiển thị mẫu giao diện Sáng / Tối
// ─────────────────────────────────────────────────────────────────────────────
class _ThemePreviewCard extends StatelessWidget {
  final String label;
  final bool isLight;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePreviewCard({
    required this.label,
    required this.isLight,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isLight ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
    final cardBg = isLight ? Colors.white : const Color(0xFF2C2C2E);
    final textColor = isLight ? const Color(0xFF1C1C1E) : Colors.white;
    final subColor = isLight ? const Color(0xFF8E8E93) : const Color(0xFF636366);
    final primaryColor =
        isLight ? const Color(0xFF007AFF) : const Color(0xFF0A84FF);
    final selectedBorderColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? selectedBorderColor : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            children: [
              // ── Mini app preview ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mini nav bar
                    Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: subColor.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 7,
                            decoration: BoxDecoration(
                              color: textColor.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Mini post card 1
                    _MiniCard(cardBg: cardBg, primaryColor: primaryColor,
                        textColor: textColor, subColor: subColor),
                    const SizedBox(height: 6),
                    // Mini post card 2 (partial)
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: subColor.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              height: 5,
                              decoration: BoxDecoration(
                                color: textColor.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Label + checkmark ─────────────────────────────────
              Container(
                color: cardBg.withValues(alpha: 0.6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? primaryColor : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? primaryColor
                              : subColor.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded,
                              size: 13, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final Color cardBg;
  final Color primaryColor;
  final Color textColor;
  final Color subColor;

  const _MiniCard({
    required this.cardBg,
    required this.primaryColor,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 30,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Container(
                width: 30,
                height: 5,
                decoration: BoxDecoration(
                  color: subColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 20,
                height: 5,
                decoration: BoxDecoration(
                  color: subColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode Selection Row
// ─────────────────────────────────────────────────────────────────────────────
class _ModeRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? primaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? primaryColor
                      : theme.hintColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
