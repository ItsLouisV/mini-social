import 'package:flutter/material.dart';

enum AppLanguage {
  vi('vi', 'Tiếng Việt', '🇻🇳', Locale('vi', 'VN')),
  en('en', 'English', '🇺🇸', Locale('en', 'US')),
  zh('zh', '中文 (Chinese)', '🇨🇳', Locale('zh', 'CN')),
  ja('ja', '日本語 (Japanese)', '🇯🇵', Locale('ja', 'JP')),
  ko('ko', '한국어 (Korean)', '🇰🇷', Locale('ko', 'KR')),
  ru('ru', 'Русский (Russian)', '🇷🇺', Locale('ru', 'RU')),
  th('th', 'ไทย (Thai)', '🇹🇭', Locale('th', 'TH')),
  es('es', 'Español (Spanish)', '🇪🇸', Locale('es', 'ES')),
  fr('fr', 'Français (French)', '🇫🇷', Locale('fr', 'FR'));

  final String code;
  final String displayName;
  final String flag;
  final Locale locale;

  const AppLanguage(this.code, this.displayName, this.flag, this.locale);

  static AppLanguage fromCode(String? code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.vi,
    );
  }
}
