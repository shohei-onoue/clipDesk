import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';

/// ベルアイコン付きのお知らせカード。
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.text,
    this.background = Colors.white,
    this.borderColor = AppColors.amber,
    this.bellColor = AppColors.amber,
    this.onTap,
  });

  final String text;
  final Color background;
  final Color borderColor;
  final Color bellColor;
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
          color: background,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(r.x(16)),
        ),
        child: Row(
          children: [
            Icon(Icons.notifications, size: r.x(24), color: bellColor),
            SizedBox(width: r.x(10)),
            Expanded(
              child: Text(text,
                  style: AppText.noto(r.x(14), height: 18.2 / 14)),
            ),
            Icon(Icons.chevron_right, size: r.x(24), color: AppColors.ink),
          ],
        ),
      ),
    );
  }
}
