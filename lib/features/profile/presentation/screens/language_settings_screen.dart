import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_language.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/localization/locale_provider.dart';

class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

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
                          HapticFeedback.mediumImpact();
                          ref
                              .read(appLanguageProvider.notifier)
                              .setLanguage(lang);
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
