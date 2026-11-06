import 'package:flutter/material.dart';

/// デザイン基準 390×844 に対する画面サイズの比率で寸法を計算する。
/// x(): 横方向・文字・アイコンなど（幅の比率）
/// y(): 縦方向の余白・高さ（高さの比率）
class Responsive {
  Responsive(Size size)
      : _w = size.width / 390,
        _h = size.height / 844;

  final double _w;
  final double _h;

  double x(double v) => v * _w;
  double y(double v) => v * _h;
}

extension ResponsiveContext on BuildContext {
  Responsive get r => Responsive(MediaQuery.sizeOf(this));
}
