import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';

/// 進捗リング（円グラフ）。中央に文字を表示する。
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, required this.label});

  /// 0.0〜1.0
  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final size = r.x(64);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value, r.x(5)),
        child: Center(
          child: Text(label,
              style: AppText.noto(r.x(16), height: 20.8 / 16)),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.stroke);

  final double value;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.ink;
    canvas.drawCircle(rect.center, size.width / 2 - 0.5, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.blue;
    canvas.drawArc(
      rect.deflate(stroke / 2),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.stroke != stroke;
}
