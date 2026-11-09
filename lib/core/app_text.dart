import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'responsive.dart';

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

  // --- デザインシステム（tokens.json の type）。サイズは画面幅に合わせて r で拡縮する。 ---

  /// h2：セクション見出し 20/30。
  static TextStyle h2(Responsive r, {Color color = AppColors.ink}) =>
      noto(r.x(20), color: color, height: 30 / 20);

  /// h3：カード・パネルの見出し 16/26。
  static TextStyle h3(Responsive r, {Color color = AppColors.ink}) =>
      noto(r.x(16), color: color, height: 26 / 16);

  /// body：指示文・説明 14/24。
  static TextStyle body(Responsive r,
          {Color color = AppColors.ink, FontWeight weight = FontWeight.w400}) =>
      noto(r.x(14), weight: weight, color: color, height: 24 / 14);

  /// body-sm：補足・ヒント 12/20。
  static TextStyle bodySm(Responsive r, {Color color = AppColors.inkMuted}) =>
      noto(r.x(12), weight: FontWeight.w400, color: color, height: 20 / 12);

  /// label：タグ・ラベル 12/16 太字。
  static TextStyle label(Responsive r, {Color color = AppColors.ink}) =>
      noto(r.x(12), color: color, height: 16 / 12);

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
