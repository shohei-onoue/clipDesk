import 'package:flutter/material.dart';

/// アプリで使う色は、Figma（ColorsList 273:1217）の4色だけ。
/// 薄い面・区切り線・補足文などは、この4色に透明度をかけて作る（例：white.withValues(alpha: 0.08)）。
class AppColors {
  AppColors._();

  /// 黒（背景・文字）。
  static const Color ink = Color(0xFF1A1D20);

  /// オレンジ（強調・注意・進捗）。
  static const Color amber = Color(0xFFD97706);

  /// 青（主操作・選択）。
  static const Color blue = Color(0xFF0052CC);

  /// 白（暗い面の上の文字・カード面）。
  static const Color white = Color(0xFFF5F5F5);

  /// 通知の件数バッジ専用の赤（利用者の指示。4色の例外。ほかの用途には使わない）。
  static const Color badgeRed = Color(0xFFD32F2F);
}
