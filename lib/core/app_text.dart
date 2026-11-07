import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppText {
  AppText._();

  static TextStyle noto(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.ink,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: 'NotoSansJP',
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle oswald(
    double size, {
    Color color = Colors.white,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.oswald(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
}
