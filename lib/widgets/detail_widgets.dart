import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_tokens.dart';
import '../core/responsive.dart';

// 案件詳細（RequestDetailScreen）と指示書確認（BriefConfirmScreen）で共有する部品。

class DetailCard extends StatelessWidget {
  const DetailCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.x(14)),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(r.x(15)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.only(top: r.y(6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: r.x(80),
              child: Text(label,
                  style: AppText.dark(r.x(14),
                      weight: FontWeight.w400,
                      color: AppColors.white.withValues(alpha: 0.7)))),
          Expanded(
              child: Text(value,
                  style: AppText.dark(r.x(14), weight: FontWeight.w400))),
        ],
      ),
    );
  }
}

class DetailButton extends StatelessWidget {
  const DetailButton(this.label, this.color, this.busy, this.onTap,
      {super.key, this.disabled = false});
  final String label;
  final Color color;

  /// 処理中。ボタンの中に進行表示を出し、押せなくする。
  final bool busy;

  /// 押せない状態（ラベルは出したまま、灰色にする）。
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final radius = BorderRadius.circular(AppRadius.md);
    // 塗りの上の文字：blue の上は white、white の上は amber、amber の上は ink。
    final fg = color == AppColors.blue
        ? AppColors.white
        : color == AppColors.white
            ? AppColors.amber
            : AppColors.ink;
    return Material(
      color: busy || disabled ? AppColors.white.withValues(alpha: 0.16) : color,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: busy || disabled ? null : onTap,
        child: SizedBox(
          height: r.x(48),
          width: double.infinity,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.white))
                : Text(label,
                    textAlign: TextAlign.center,
                    style: AppText.noto(r.x(14),
                        color: disabled
                            ? AppColors.white.withValues(alpha: 0.7)
                            : fg,
                        height: 20 / 14)),
          ),
        ),
      ),
    );
  }
}

/// 画面上部のお知らせ（琥珀の枠）。
class NoticeBar extends StatelessWidget {
  const NoticeBar(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: r.x(49)),
      padding: EdgeInsets.symmetric(horizontal: r.x(14), vertical: r.x(12)),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.amber, width: 2),
        borderRadius: BorderRadius.circular(r.x(15)),
      ),
      child: Text(text, style: AppText.dark(r.x(14), height: 21 / 14)),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.x(4)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppText.dark(r.x(12),
                  weight: FontWeight.w400,
                  color: AppColors.white.withValues(alpha: 0.7),
                  height: 20 / 12)),
          SizedBox(width: r.x(8)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: AppText.dark(r.x(14),
                    weight: FontWeight.w400, height: 20 / 14)),
          ),
        ],
      ),
    );
  }
}
