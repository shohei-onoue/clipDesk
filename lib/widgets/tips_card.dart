import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';

/// ヒント用のカード。左上に「TIPS」ラベル（amber）、背景は White、本文は ink。
class TipsCard extends StatelessWidget {
  const TipsCard(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.x(14)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(r.x(15)),
      ),
      // 行の上下の余白（行間の半分）を除いて、カードの上下のパディングを見た目で揃える。
      child: DefaultTextHeightBehavior(
        textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false, applyHeightToLastDescent: false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TIPS', style: AppText.noto(r.x(18), color: AppColors.amber)),
            SizedBox(height: r.x(4)),
            Text(text,
                style: AppText.noto(r.x(13),
                    weight: FontWeight.w400,
                    color: AppColors.ink,
                    height: 1.6)),
          ],
        ),
      ),
    );
  }
}
