import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_settings.dart';

/// 部品ごとの色（Figma「部品一覧」416:76：利用者が配色パターンごとに編集した指定）。
/// 基本は [AppColors] の5色。部品や組み合わせによって別の色を使うところだけ、ここで決める。
class PartColors {
  PartColors._();

  static AppPalette get _p => AppSettings.instance.palette;

  static const Color _black = Color(0xFF111111);
  static const Color _paper = Color(0xFFF5F5F5);

  /// 青と琥珀の両方が明るい組み合わせ（ハイコントラスト・クリア・オーシャン・フォレスト）。
  static bool get _vivid =>
      _p == AppPalette.contrast ||
      _p == AppPalette.ocean ||
      _p == AppPalette.forest;

  /// 未読の通知のベル（全組み合わせ共通の黄色）。
  static const Color unreadBell = Color(0xFFFFD600);

  /// 琥珀の塗り（バッジ・ボタン）の上の文字。デフォルトは白。
  static Color get onAmber => _p == AppPalette.standard
      ? AppColors.white
      : AppColors.on(AppColors.amber);

  /// 枠だけの状態バッジ（white の面）の文字。[accent] は枠の色（amber か blue）。
  static Color outlinedBadgeText(Color accent) => switch (_p) {
        AppPalette.standard => accent,
        AppPalette.ocean => accent == AppColors.amber ? _black : accent,
        AppPalette.contrast || AppPalette.forest => _black,
        AppPalette.light => _paper,
      };

  /// DetailButton の塗り。[kind] は呼び出し側の指定（blue＝主操作・amber・white）。
  /// 明るい色の組み合わせでは、青と琥珀を入れ替える。
  static Color detailFill(Color kind) {
    if (kind == AppColors.white) {
      return AppColors.isLight ? _paper : AppColors.white;
    }
    if (!_vivid) return kind;
    return kind == AppColors.blue ? AppColors.amber : AppColors.blue;
  }

  /// DetailButton の文字。白いボタンは赤い文字。
  static Color detailText(Color kind) {
    if (kind == AppColors.white) {
      return AppColors.isLight ? AppColors.amber : AppColors.badgeRed;
    }
    return detailFill(kind) == AppColors.amber
        ? onAmber
        : AppColors.on(AppColors.blue);
  }

  /// 押せないボタンの文字。
  static Color get disabledButtonText =>
      _p == AppPalette.forest || _p == AppPalette.light
          ? AppColors.blue
          : AppColors.white.withValues(alpha: 0.7);

  /// 処理中のボタンの進行表示。
  static Color busySpinner(Color kind) => switch (_p) {
        AppPalette.ocean => AppColors.amber,
        AppPalette.light => AppColors.white,
        _ => detailText(kind),
      };

  /// オンのスイッチと、右下の「＋」ボタン（FAB）の塗り。
  static Color get toggleFill =>
      _p == AppPalette.ocean ? AppColors.amber : AppColors.blue;

  /// 「TIPS」ラベル。
  static Color get tipsLabel => _p == AppPalette.ocean || _p == AppPalette.light
      ? AppColors.blue
      : AppColors.amber;

  /// ログイン画面の「ログイン」ボタンの文字。
  static Color get loginButtonText => _vivid ? _black : Colors.white;

  /// 招待の「再送」ボタンの塗りと文字。
  static Color get resendFill =>
      AppColors.isLight ? AppColors.blue : AppColors.amber;

  static Color get resendText =>
      AppColors.isLight ? _paper : (_vivid ? _black : AppColors.white);

  /// 赤（[AppColors.badgeRed]）のボタンの上の文字。
  static Color get onRed => AppColors.isLight ? _paper : AppColors.white;

  static bool get _ownDrawerFooter =>
      _p == AppPalette.forest || _p == AppPalette.light;

  /// ドロワー下部（名前・ログアウトのアイコン・バージョン）の色。
  static Color get drawerFooter =>
      _ownDrawerFooter ? AppColors.on(AppColors.amber) : _black;

  /// ドロワーの「Version」。
  static Color get drawerVersion => drawerFooter.withValues(
      alpha: _p == AppPalette.standard || _p == AppPalette.contrast ? 1 : 0.7);
}
