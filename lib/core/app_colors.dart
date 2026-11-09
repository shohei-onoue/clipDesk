import 'package:flutter/material.dart';

/// Figma「Clipdesk 全画面」の色。
class AppColors {
  AppColors._();

  static const Color bg = Color(0xFFD6DADE);
  static const Color blue = Color(0xFF0052CC);
  static const Color ink = Color(0xFF1A1D20);
  static const Color amber = Color(0xFFD97706);

  /// 期限超過など、強い警告（tokens.json の danger。必ず語句を併記する）。
  static const Color danger = Color(0xFFB3261E);

  /// 注意・要確認の文字とアイコン（tokens.json の warn）。surface 上で使える。
  static const Color warn = Color(0xFF8A4B00);
  static const Color stepBorder = Color(0xFF738095);
  static const Color stepGrey = Color(0xFF435169);
  static const Color hint = Color(0xFF8795AB);
  static const Color loginBg = Color(0xFF1A1A1F);
  static const Color avatar = Color(0xFFD2BFB9);
  static const Color ringTrack = Color(0xFF738095);

  // --- デザインシステム（docs/design-system/tokens.json、ライト） ---
  /// カード・入力欄。bg の上に置く。
  static const Color surface200 = Color(0xFFF4F6F7);

  /// タイムライン背景、凹んだ領域。
  static const Color surface300 = Color(0xFFC3C8CD);

  /// 補足文。bg / surface 上で 4.5:1 以上。
  static const Color inkMuted = Color(0xFF3F444A);

  /// 区切り線（装飾のみ）。
  static const Color line = Color(0xFFB4BAC0);

  /// 入力欄・ボタンの枠。bg / surface 上で 3:1 以上。
  static const Color lineStrong = Color(0xFF6B727A);

  /// blue 塗りの上の文字。
  static const Color onBlue = Color(0xFFFFFFFF);

  /// amber 塗りの上の文字（5.3:1）。
  static const Color onAmber = Color(0xFF1A1D20);

  /// ボットの吹き出し背景。
  static const Color bubbleBot = Color(0xFFDBE6F7);
}
