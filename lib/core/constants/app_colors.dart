import 'package:flutter/cupertino.dart';

class AppColors {
  AppColors._();

  // iOS system palette
  static const Color primary = CupertinoColors.systemBlue;
  static const Color primaryLight = Color(0xFFEAF4FF);
  static const Color primaryDark = Color(0xFF0051D5);

  // Secondary
  static const Color secondary = CupertinoColors.systemPink;
  static const Color secondaryLight = Color(0xFFFFE8F0);

  // Neutral (Light Mode)
  static const Color background = CupertinoColors.systemGroupedBackground;
  static const Color surface = CupertinoColors.systemBackground;
  static const Color surfaceVariant = CupertinoColors.secondarySystemGroupedBackground;
  static const Color border = CupertinoColors.separator;

  // Neutral (Dark Mode)
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2E);
  static const Color darkBorder = Color(0xFF38383A);

  // Text
  static const Color textPrimary = CupertinoColors.label;
  static const Color textSecondary = CupertinoColors.secondaryLabel;
  static const Color textHint = CupertinoColors.tertiaryLabel;
  static const Color textOnPrimary = CupertinoColors.white;

  // Dark text
  static const Color darkTextPrimary = CupertinoColors.white;
  static const Color darkTextSecondary = Color(0xFFAEAEB2);

  // Status
  static const Color success = CupertinoColors.systemGreen;
  static const Color error = CupertinoColors.systemRed;
  static const Color warning = CupertinoColors.systemOrange;
  static const Color info = CupertinoColors.systemBlue;

  // Like
  static const Color like = CupertinoColors.systemRed;
  static const Color likeInactive = CupertinoColors.tertiaryLabel;

  // Shimmer
  static const Color shimmerBase = Color(0xFFE8E8F0);
  static const Color shimmerHighlight = Color(0xFFF8F8FF);
  static const Color darkShimmerBase = Color(0xFF2A2A42);
  static const Color darkShimmerHighlight = Color(0xFF3A3A56);
}
