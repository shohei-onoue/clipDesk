import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import 'progress_ring.dart';

/// 依頼カード（リング / 依頼名 / 担当・納期 / 状態タグ）。
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.progress,
    required this.progressLabel,
    required this.title,
    required this.meta,
    required this.tag,
    this.tagColor = AppColors.blue,
    this.tagTextColor = AppColors.bg,
  });

  final double progress;
  final String progressLabel;
  final String title;
  final String meta;
  final String tag;
  final Color tagColor;
  final Color tagTextColor;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: r.y(92)),
      padding: EdgeInsets.all(r.x(14)),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.ink),
        borderRadius: BorderRadius.circular(r.x(15)),
      ),
      child: Row(
        children: [
          ProgressRing(value: progress, label: progressLabel),
          SizedBox(width: r.x(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.noto(r.x(16), height: 20.8 / 16)),
                SizedBox(height: r.y(4)),
                Text(meta,
                    style: AppText.noto(r.x(14),
                        weight: FontWeight.w500, height: 18.2 / 14)),
                SizedBox(height: r.y(4)),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.x(16), vertical: r.y(5)),
                  decoration: BoxDecoration(
                    color: tagColor,
                    border: Border.all(color: AppColors.ink),
                    borderRadius: BorderRadius.circular(r.x(16)),
                  ),
                  child: Text(tag,
                      style: AppText.noto(r.x(15),
                          color: tagTextColor, height: 19.5 / 15)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
