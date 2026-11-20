import 'app_settings.dart';
import 'package:flutter/material.dart';

/// アプリで使う色は、Figma（ColorsList 273:1217）の4色（ink・white・amber・blue）と、
/// 面に使うグレー（gray）。設定画面で選んだ「色の組み合わせ」（[AppPalette]）に合わせて変わる。
/// 既定（デフォルト）は従来の配色。薄い線・補足文などは、これらに透明度をかけて作る
/// （例：white.withValues(alpha: 0.7)）。
///
/// 色は設定で変わるため const ではない（`const` の中では使えない）。
class AppColors {
  AppColors._();

  static AppPalette get _p => AppSettings.instance.palette;

  /// 黒（背景・文字）。
  static Color get ink => _p.ink;

  /// オレンジ（強調・注意・進捗）。
  static Color get amber => _p.amber;

  /// 青（主操作・選択）。
  static Color get blue => _p.blue;

  /// 白（暗い面の上の文字・カード面）。
  static Color get white => _p.white;

  /// 面（カード・入力欄・情報面の背景）のグレー。従来は白 8%（半透明）。
  static Color get gray => _p.gray;

  /// 画面・ダイアログの背景。デフォルトでは ink と同じ。
  static Color get bg => _p.bg;

  /// グラデーション（メインカード・ドロワー）の濃い側。
  static Color get deep => _p.deep;

  /// ドロワーのグラデーションの終わり側。
  static Color get drawerEnd => _p.drawerEnd ?? _p.blue;

  /// 青で塗った面（ボタン・バッジ・自分の吹き出し）の上の文字。デフォルトでは white と同じ。
  static Color get onBlue => _p.onBlue;

  /// 琥珀で塗った面の上の文字。デフォルトでは ink と同じ。
  static Color get onAmber => _p.onAmber;

  /// 琥珀の小さなバッジの文字（デフォルトは white）。
  static Color get badgeOnAmber => _p.badgeOnAmber;

  /// いつも暗い面（動画・黒い背景・赤いバッジ）の上の明るい文字・アイコン。
  static Color get onDark => _p.onDark;

  /// いつも白い面（ログインの入力欄）の上の暗い文字。
  static Color get onLight => _p.onLight;

  /// 明るい背景の配色か（標準の部品の明暗を切り替える）。
  static bool get isLight => _p.isLight;

  /// 通知の件数バッジ専用の赤（利用者の指示。ほかの色の例外で、組み合わせを変えても変わらない）。
  static const Color badgeRed = Color(0xFFD32F2F);
}
