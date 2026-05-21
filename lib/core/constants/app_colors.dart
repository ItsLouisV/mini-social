import 'package:flutter/cupertino.dart';

class AppColors {
  AppColors._();

  // Primary Accent (Vibrant Blue from the "Allow" & "Play" buttons)
  static const Color primary = Color(0xFF0D68F9); // Vivid blue
  static const Color primaryLight = Color(0xFFE5EFFF);
  static const Color primaryDark = Color(0xFF004EC2);

  // Secondary Accent (Red/Pink from the "Delete" button)
  static const Color secondary = Color(0xFFFC2A35); // Vivid red/pink
  static const Color secondaryLight = Color(0xFFFFE8EA);

  // Neutral (Light Mode)
  static const Color background = Color(0xFFF2F2F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE5E5EA);
  static const Color border = Color(0xFFD1D1D6);

  // Neutral (Dark Mode) - Based on the deep blueish-grey in the image
  static const Color darkBackground = Color(0xFF1B1B25); // Deep background
  static const Color darkSurface = Color(0xFF262635); // Elevated cards
  static const Color darkSurfaceVariant = Color(0xFF353545); // Buttons/Toggles background on dark
  static const Color darkBorder = Color(0xFF3A3A4A);

  // Text
  static const Color textPrimary = CupertinoColors.black;
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textHint = Color(0xFFC7C7CC);
  static const Color textOnPrimary = CupertinoColors.white;

  // Dark text
  static const Color darkTextPrimary = CupertinoColors.white;
  static const Color darkTextSecondary = Color(0xFFA0A0AB); // Soft grey-blue for subtitles

  // Status
  static const Color success = Color(0xFF34C759); // Green toggle in the image
  static const Color error = Color(0xFFFC2A35);
  static const Color warning = Color(0xFFFF9F0A); // Orange icon
  static const Color info = Color(0xFF0D68F9); // Blue icon
  static const Color flag = Color(0xFFBF5AF2); // Purple flag icon

  // Like
  static const Color like = Color(0xFFFC2A35);
  static const Color likeInactive = Color(0xFF8E8E93);

  // Shimmer
  static const Color shimmerBase = Color(0xFFEBEBF0);
  static const Color shimmerHighlight = Color(0xFFF2F2F7);
  static const Color darkShimmerBase = Color(0xFF262635);
  static const Color darkShimmerHighlight = Color(0xFF353545);

  // Chat
  static const Color chatBubbleSender = primary;
  static const Color chatBubbleReceiver = surfaceVariant;
  static const Color chatTextSender = CupertinoColors.white;
  static const Color chatTextReceiver = CupertinoColors.black;

  static const Color darkChatBubbleSender = primary;
  static const Color darkChatBubbleReceiver = darkSurfaceVariant;
  static const Color darkChatTextSender = CupertinoColors.white;
  static const Color darkChatTextReceiver = CupertinoColors.white;

  // Chat Input
  static const Color chatInputSendEnabled = primary;
  static const Color chatInputSendDisabled = Color(0xFFE5E5EA);
  static const Color darkChatInputSendDisabled = Color(0xFF353545);
  static const Color chatInputSendIconEnabled = CupertinoColors.white;
  static const Color chatInputSendIconDisabled = Color(0xFF8E8E93);
}
