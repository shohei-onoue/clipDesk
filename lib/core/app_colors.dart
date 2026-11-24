import 'app_settings.dart';
import 'package:flutter/material.dart';

/// アプリで使う色は、Figma（ColorsList 273:1217）の4色（ink・white・amber・blue）と、
/// 面に使うグレー（gray）の5色だけ。設定画面で選んだ「色の組み合わせ」（[AppPalette]）に
/// 合わせて変わる。背景は ink、青・琥珀の面の上の文字は [on] で決める。
/// 薄い線・補足文などは、これらに透明度をかけて作る（例：white.withValues(alpha: 0.7)）。
///
/// 色は設定で変わるため const ではない（`const` の中では使えない）。
class AppColors {
  AppColors._();

  static AppPalette get _p => AppSettings.instance.palette;

  /// 黒（画面・ダイアログの背景）。white の反対色。
  static Color get ink => _p.ink;

  /// オレンジ（強調・注意・進捗）。
  static Color get amber => _p.amber;

  /// 青（主操作・選択）。
  static Color get blue => _p.blue;

  /// 白（暗い面の上の文字・カード面）。
  static Color get white => _p.white;

  /// 面（カード・入力欄・情報面の背景）のグレー。従来は白 8%（半透明）。
  static Color get gray => _p.gray;

  /// 面の上で読みやすい文字色（white か ink）。
  /// 青の面は `on(blue)`、琥珀の面は `on(amber)`、いつも暗い面（動画など）は `on(Colors.black)`、
  /// 濃い側の色（ドロワーなど）は `on(Colors.white)`。
  static Color on(Color surface) => _p.on(surface);

  /// 明るい背景の配色か。
  static bool get isLight => _p.isLight;

  /// 通知の件数バッジ専用の赤（利用者の指示。ほかの色の例外で、組み合わせを変えても変わらない）。
  static const Color badgeRed = Color(0xFFD32F2F);
}
