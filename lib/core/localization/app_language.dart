import 'package:flutter/material.dart';

enum AppLanguage {
  vi('vi', 'Tiếng Việt', '🇻🇳', Locale('vi', 'VN')),
  en('en', 'English', '🇺🇸', Locale('en', 'US'));

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
