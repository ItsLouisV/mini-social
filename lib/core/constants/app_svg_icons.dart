import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppSvgIcons {
  static const String plusSquare = 'assets/icons/plus_square.svg';

  /// Helper render SvgPicture từ asset
  static Widget svg(
    String assetPath, {
    double? width,
    double? height,
    Color? color,
    BoxFit fit = BoxFit.contain,
  }) {
    return SvgPicture.asset(
      assetPath,
      width: width,
      height: height,
      colorFilter: color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
      fit: fit,
    );
  }
}
