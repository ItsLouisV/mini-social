import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_language.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../feed/providers/feed_provider.dart';

class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  void _showConfirmationDialog(
    BuildContext context,
    WidgetRef ref, {
    required AppLanguage currentLang,
    required AppLanguage targetLang,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          title: Row(
            children: [
              Text(targetLang.flag, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Đổi ngôn ngữ',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Bạn có chắc chắn muốn chuyển sang ${targetLang.displayName} (${targetLang.flag})?\n\nỨng dụng sẽ áp dụng cài đặt mới và tự động nạp lại trang Bảng tin trong giây lát.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Hủy',
                style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _startLanguageTransition(context, ref, currentLang: currentLang, targetLang: targetLang);
              },
              child: const Text('Đồng ý', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _startLanguageTransition(
    BuildContext context,
    WidgetRef ref, {
    required AppLanguage currentLang,
    required AppLanguage targetLang,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _LanguageLoadingDialog(
          currentLang: currentLang,
          targetLang: targetLang,
          onCompleted: () {
            ref.read(appLanguageProvider.notifier).setLanguage(targetLang);
            ref.invalidate(feedPostsProvider);
            if (context.mounted) {
              context.go('/feed');
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppTranslations.tr(ref, 'language'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                AppTranslations.tr(ref, 'select_language').toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.hintColor,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: AppLanguage.values.asMap().entries.map((entry) {
                  final index = entry.key;
                  final lang = entry.value;
                  final isSelected = lang == currentLang;

                  return Column(
                    children: [
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: index == 0
                                ? const Radius.circular(16)
                                : Radius.zero,
                            bottom: index == AppLanguage.values.length - 1
                                ? const Radius.circular(16)
                                : Radius.zero,
                          ),
                        ),
                        leading: Text(
                          lang.flag,
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          lang.displayName,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                CupertinoIcons.checkmark_alt,
                                color: theme.colorScheme.primary,
                                size: 22,
                              )
                            : null,
                        onTap: () {
                          if (isSelected) return;
                          HapticFeedback.mediumImpact();
                          _showConfirmationDialog(
                            context,
                            ref,
                            currentLang: currentLang,
                            targetLang: lang,
                          );
                        },
                      ),
                      if (index < AppLanguage.values.length - 1)
                        Divider(
                          height: 1,
                          indent: 56,
                          endIndent: 16,
                          color: theme.dividerColor.withValues(alpha: 0.15),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageLoadingDialog extends ConsumerStatefulWidget {
  final AppLanguage currentLang;
  final AppLanguage targetLang;
  final VoidCallback onCompleted;

  const _LanguageLoadingDialog({
    required this.currentLang,
    required this.targetLang,
    required this.onCompleted,
  });

  @override
  ConsumerState<_LanguageLoadingDialog> createState() => _LanguageLoadingDialogState();
}

class _LanguageLoadingDialogState extends ConsumerState<_LanguageLoadingDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _controller.addListener(() {
      setState(() {});
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onCompleted();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getStatusText(double progress) {
    if (progress < 0.3) {
      return 'Đang lưu cấu hình ngôn ngữ mới...';
    } else if (progress < 0.65) {
      return 'Đang áp dụng giao diện & bản dịch ${widget.targetLang.displayName}...';
    } else if (progress < 0.9) {
      return 'Đang làm mới dữ liệu Bảng tin...';
    } else {
      return 'Hoàn tất! Đang mở Bảng tin...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = _controller.value;
    final remainingSeconds = (10 * (1.0 - progress)).ceil().clamp(0, 10);
    final percent = (progress * 100).toInt().clamp(0, 100);

    return PopScope(
      canPop: false,
      child: Dialog.fullscreen(
        backgroundColor: isDark ? const Color(0xFF0D0E15) : const Color(0xFFF4F6F9),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Animated flags & progress ring
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.25),
                        blurRadius: 36,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 6,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.currentLang.flag, style: const TextStyle(fontSize: 34)),
                          const SizedBox(width: 8),
                          Icon(
                            CupertinoIcons.arrow_right,
                            color: theme.colorScheme.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(widget.targetLang.flag, style: const TextStyle(fontSize: 34)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // Language title
                Text(
                  'Đang chuyển sang ${widget.targetLang.displayName}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Dynamic Status Message
                Text(
                  _getStatusText(progress),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Progress Bar & Timer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: isDark ? Colors.white10 : Colors.black12,
                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tiến trình: $percent%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Còn $remainingSeconds s',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Subtitle footer
                Text(
                  'Vui lòng không đóng ứng dụng trong quá trình đồng bộ...',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.hintColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
