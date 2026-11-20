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

/// タップで編集できる内容テキスト。下線つきのテキストボタンとして見せる。
class TapEditText extends StatelessWidget {
  const TapEditText(this.text,
      {super.key,
      required this.label,
      required this.style,
      required this.onTap,
      this.textAlign});
  final String text;
  final String label;
  final TextStyle style;

  /// タップした画面上の位置を渡す（メニューをその場に出すため）。
  final void Function(Offset at) onTap;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$labelを編集',
        child: InkWell(
          onTapUp: (d) => onTap(d.globalPosition),
          onTap: () {},
          borderRadius: BorderRadius.circular(4),
          child: Text(text,
              textAlign: textAlign,
              style: style.copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: style.color)),
        ),
      );
}

class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key, this.onEdit, this.child});
  final String label;
  final String value;

  /// 指定すると、内容のテキストがボタンになり、タップで編集できる。
  final void Function(Offset at)? onEdit;

  /// 内容を独自の部品で出したいとき（複数の編集箇所があるとき）に指定する。
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.only(top: r.y(6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: Text(label,
                  style: AppText.dark(r.x(14),
                      weight: FontWeight.w400,
                      color: AppColors.white.withValues(alpha: 0.7)))),
          Expanded(
            child: child ??
                (onEdit == null
                    ? Text(value,
                        style: AppText.dark(r.x(14), weight: FontWeight.w400))
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: TapEditText(value,
                            label: label,
                            onTap: onEdit!,
                            style: AppText.dark(r.x(14),
                                weight: FontWeight.w400)))),
          ),
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

/// 画面上部のお知らせ（枠線なし）。
class NoticeBar extends StatelessWidget {
  const NoticeBar(this.text, {super.key});
  final String text;

  /// 背景は白で、枠はつけない。文字は暗い色。
  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: r.x(49)),
      padding: EdgeInsets.symmetric(horizontal: r.x(14), vertical: r.x(12)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(r.x(15)),
      ),
      child: Text(text, style: AppText.noto(r.x(14), height: 21 / 14)),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.onEdit});
  final String label;
  final String value;

  /// 指定すると、内容のテキストがボタンになり、タップで編集できる。
  final void Function(Offset at)? onEdit;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.x(4)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: AppText.dark(r.x(12),
                    weight: FontWeight.w400,
                    color: AppColors.white.withValues(alpha: 0.7),
                    height: 20 / 12)),
          ),
          Expanded(
            child: onEdit == null
                ? Text(value,
                    style: AppText.dark(r.x(14),
                        weight: FontWeight.w400, height: 20 / 14))
                : Align(
                    alignment: Alignment.centerLeft,
                    child: TapEditText(value,
                        label: label,
                        onTap: onEdit!,
                        style: AppText.dark(r.x(14),
                            weight: FontWeight.w400, height: 20 / 14))),
          ),
        ],
      ),
    );
  }
}
