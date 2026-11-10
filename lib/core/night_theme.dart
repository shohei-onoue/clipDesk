import 'package:flutter/material.dart';

import 'app_colors.dart';

/// ダーク背景の画面で、標準のウィジェット（入力欄・チップ・スイッチ・リスト・ボタン）の色をそろえるテーマ。
/// 値は tokens.json の dark。画面の Scaffold を `Theme(data: nightTheme, ...)` で包んで使う。
/// 塗りボタンは、画面側で brand（on-brand の文字）か accent（on-accent の文字）を明示する。
final ThemeData nightTheme = _build();

ThemeData _build() {
  final base = ThemeData.dark(useMaterial3: true);
  final outline = OutlineInputBorder(
    borderSide: BorderSide(color: AppColors.white.withValues(alpha: 0.55)),
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.ink,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.blue,
      onPrimary: AppColors.white,
      surface: AppColors.white.withValues(alpha: 0.08),
      onSurface: AppColors.white,
      onSurfaceVariant: AppColors.white.withValues(alpha: 0.7),
      outline: AppColors.white.withValues(alpha: 0.55),
      error: AppColors.amber,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'NotoSansJP',
      bodyColor: AppColors.white,
      displayColor: AppColors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: outline,
      enabledBorder: outline,
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.blue, width: 2),
      ),
      labelStyle: TextStyle(color: AppColors.white.withValues(alpha: 0.7)),
      hintStyle: TextStyle(color: AppColors.white.withValues(alpha: 0.7)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.transparent,
      selectedColor: AppColors.blue,
      checkmarkColor: AppColors.white,
      side: BorderSide(color: AppColors.white.withValues(alpha: 0.55)),
      labelStyle: const TextStyle(color: AppColors.white),
      secondaryLabelStyle: const TextStyle(color: AppColors.white),
    ),
    listTileTheme: ListTileThemeData(
      textColor: AppColors.white,
      iconColor: AppColors.white,
      subtitleTextStyle:
          TextStyle(color: AppColors.white.withValues(alpha: 0.7)),
    ),
    dividerColor: AppColors.white.withValues(alpha: 0.16),
  );
}
