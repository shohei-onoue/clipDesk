import 'package:flutter/material.dart' hide Text;

import '../core/app_colors.dart';
import '../core/part_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import 'app_icon.dart';
import 'ruby_text.dart';

/// ベルアイコン付きのお知らせカード。
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.text,
    this.caption,
    this.background,
    Color? borderColor,
    Color? bellColor,
    this.onTap,
  })  : _borderColor = borderColor,
        _bellColor = bellColor;

  final String text;

  /// タイトルの上に小さく出す文字（通知された日付など）。
  final String? caption;
  final Color? background;
  final Color? _borderColor;
  final Color? _bellColor;
  Color get borderColor => _borderColor ?? AppColors.amber;
  Color get bellColor => _bellColor ?? PartColors.unreadBell;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(r.x(14)),
        decoration: BoxDecoration(
          color: background ?? AppColors.gray,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(r.x(15)),
        ),
        child: Row(
          children: [
            AppIcon(AppIcons.notificationsFill,
                size: r.x(28), color: bellColor),
            SizedBox(width: r.x(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (caption != null)
                    Text(caption!,
                        style: AppText.dark(r.x(12),
                            weight: FontWeight.w400,
                            color: AppColors.white.withValues(alpha: 0.7),
                            height: 16 / 12)),
                  Text(text,
                      style: AppText.dark(r.x(14),
                          weight: FontWeight.w400, height: 24 / 14)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: r.x(24), color: AppColors.white),
          ],
        ),
      ),
    );
  }
}
