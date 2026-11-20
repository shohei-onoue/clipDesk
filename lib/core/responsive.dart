import 'package:flutter/material.dart';

import 'app_settings.dart';

/// デザイン基準 390×844 に対する画面サイズの比率で寸法を計算する。
/// x(): 横方向・文字・アイコンなど（幅の比率）
/// y(): 縦方向の余白・高さ（高さの比率）
/// 広い画面（PCなど）では寸法が大きくなりすぎないよう、比率の幅は [maxWidth] で止める。
/// 画面は全幅に広がり、部品の大きさだけが携帯相当になる。
class Responsive {
  Responsive(Size size, {this.textScale = 1.0})
      : _w = (size.width > maxWidth ? maxWidth : size.width) / 390,
        _h = size.height / 844;

  static const double maxWidth = 430;

  final double _w;
  final double _h;

  /// 設定の「文字の大きさ」の倍率（小＝1、中＝1.5、大＝2）。
  final double textScale;

  /// 文字に合わせて大きくしたい寸法（文字を入れる枠の高さ・幅など）。
  /// [v] は標準（小）のときの値。標準のときは x(v) と同じで、文字が大きいときだけ
  /// 倍率に合わせて広げ、あふれを防ぐ。
  double tx(double v) => x(v) * textScale;

  /// 文字が大きいとき（中・大）か。
  bool get large => textScale > 1.0;

  /// ふりがなを表示する設定か（行が高くなり、横幅も広がるので、枠に余裕をもたせる）。
  bool get ruby => AppSettings.instance.ruby;

  /// 文字が大きい、またはふりがなを表示するとき。横に並べず、縦に積むなど、広い場所を使う。
  bool get roomy => large || ruby;

  double x(double v) => v * _w;
  double y(double v) => v * _h;
}

extension ResponsiveContext on BuildContext {
  Responsive get r => Responsive(MediaQuery.sizeOf(this),
      textScale: MediaQuery.textScalerOf(this).scale(1));
}
