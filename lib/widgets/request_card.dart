import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_tokens.dart';
import '../core/responsive.dart';
import 'progress_ring.dart';

/// 依頼カード（ダーク背景用。リング / 依頼名 / 担当・納期 / 状態タグ）。
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.progress,
    required this.progressLabel,
    required this.title,
    required this.meta,
    required this.tag,
    this.tagColor = AppColors.blue,
    this.tagTextColor = AppColors.white,
    this.onTap,
  });

  final double progress;
  final String progressLabel;
  final String title;
  final String meta;
  final String tag;
  final Color tagColor;
  final Color tagTextColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: r.y(92)),
          padding: EdgeInsets.all(r.x(14)),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.08),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.16)),
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
                    Text(title,
                        style: AppText.dark(r.x(16), height: 20.8 / 16)),
                    SizedBox(height: r.y(4)),
                    Text(meta,
                        style: AppText.dark(r.x(14),
                            weight: FontWeight.w400,
                            color: AppColors.white.withValues(alpha: 0.7),
                            height: 18.2 / 14)),
                    SizedBox(height: r.y(4)),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.x(8), vertical: r.y(4)),
                      decoration: BoxDecoration(
                        color: tagColor,
                        borderRadius: BorderRadius.circular(r.x(AppRadius.sm)),
                      ),
                      child: Text(tag,
                          style: AppText.noto(r.x(12),
                              color: tagTextColor, height: 16 / 12)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }
}
