import 'package:flutter/material.dart' hide Text;

import '../core/app_colors.dart';
import '../core/app_settings.dart';
import '../core/app_text.dart';
import '../core/read_aloud.dart';
import '../core/app_tokens.dart';
import '../core/responsive.dart';
import 'ruby_text.dart';

// 案件詳細（RequestDetailScreen）と指示書確認（BriefConfirmScreen）で共有する部品。

class DetailCard extends StatelessWidget {
  const DetailCard({super.key, required this.children, this.speech});
  final List<Widget> children;

  /// 音声読み上げがオンのとき、エリア右上に読み上げアイコンを出し、
  /// タップでこの文章（エリア内のテキスト全て）を読み上げる。
  final String? speech;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.x(14)),
      decoration: BoxDecoration(
        color: AppColors.gray,
        border: Border.all(color: AppColors.white.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(r.x(15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (speech != null && AppSettings.instance.readAloud)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'このエリアを読み上げる',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints:
                  BoxConstraints.tightFor(width: r.x(40), height: r.x(40)),
              onPressed: () => ReadAloud.instance.speak(speech!),
              icon: Icon(Icons.record_voice_over_outlined,
                  size: r.x(26), color: AppColors.white),
            ),
          ),
        ...children,
      ]),
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
    if (r.large) {
      // 文字が大きいとき（中・大）：「見出し→値」を縦に並べて、値の幅を広く使う。
      return Padding(
        padding: EdgeInsets.only(top: r.y(6)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppText.dark(r.x(14),
                    weight: FontWeight.w400,
                    color: AppColors.white.withValues(alpha: 0.7))),
            child ??
                (onEdit == null
                    ? Text(value,
                        style: AppText.dark(r.x(14), weight: FontWeight.w400))
                    : TapEditText(value,
                        label: label,
                        onTap: onEdit!,
                        style: AppText.dark(r.x(14), weight: FontWeight.w400))),
          ],
        ),
      );
    }
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
        ? AppColors.on(AppColors.blue)
        : color == AppColors.white
            ? AppColors.amber
            : AppColors.on(AppColors.amber);
    return Material(
      color: busy || disabled ? AppColors.white.withValues(alpha: 0.16) : color,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: busy || disabled ? null : onTap,
        child: ConstrainedBox(
          // 標準は高さ48。文字が大きいとき（中・大）は、押しやすいよう文字に合わせて高くする。
          constraints: BoxConstraints(
              minHeight: r.large ? r.x(38) * r.textScale : r.x(48),
              minWidth: double.infinity),
          child: Center(
            child: busy
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg))
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

  /// 画面上部のメッセージ。背景・枠などの図形はつけず、左に拡声器のアイコン、
  /// 大文字1文字分（文字サイズ1つ分）あけて、メッセージを出す。
  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final size = r.x(14);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.x(4), vertical: r.x(4)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.campaign_outlined, size: r.x(24), color: AppColors.white),
          SizedBox(width: size),
          Expanded(
              child: Text(text, style: AppText.dark(size, height: 21 / 14))),
        ],
      ),
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
    if (r.large) {
      // 文字が大きいとき（中・大）：「見出し→値」を縦に並べる。
      return Padding(
        padding: EdgeInsets.symmetric(vertical: r.x(4)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppText.dark(r.x(12),
                    weight: FontWeight.w400,
                    color: AppColors.white.withValues(alpha: 0.7),
                    height: 20 / 12)),
            onEdit == null
                ? Text(value,
                    style: AppText.dark(r.x(14),
                        weight: FontWeight.w400, height: 20 / 14))
                : TapEditText(value,
                    label: label,
                    onTap: onEdit!,
                    style: AppText.dark(r.x(14),
                        weight: FontWeight.w400, height: 20 / 14)),
          ],
        ),
      );
    }
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

/// 画面下などのボタンの並び。標準は横に並べる（[flexes] は幅の比）。
/// 文字が大きいとき（中・大）は、横に並べず、縦に積んで全幅にする（A案）。
class ActionRow extends StatelessWidget {
  const ActionRow({super.key, required this.children, this.flexes});
  final List<Widget> children;
  final List<int>? flexes;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    if (r.large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: r.x(12)),
            children[i],
          ],
        ],
      );
    }
    return Row(children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(width: r.x(10)),
        Expanded(flex: flexes?[i] ?? 1, child: children[i]),
      ],
    ]);
  }
}
