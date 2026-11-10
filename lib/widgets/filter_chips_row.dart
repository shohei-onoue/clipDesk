import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_tokens.dart';
import '../core/responsive.dart';

/// 進捗などの絞り込みボタン。横にスクロールでき、右端が見切れる位置には
/// 薄いぼかしを重ねて「続きがある」ことを示す。[counts] があれば件数を添える。
class FilterChipsRow extends StatelessWidget {
  const FilterChipsRow({
    super.key,
    this.selected = 0,
    this.idleColor = AppColors.white,
    this.onChanged,
    this.labels = defaultLabels,
    this.counts,
    this.wrap = false,
    this.dark = false,
  });

  static const defaultLabels = [
    'すべて',
    '受付待ち',
    '要確認',
    '編集中',
    '初稿確認',
    '修正',
    '投稿済',
  ];
  final List<String> labels;

  /// labels と同じ並びの件数。null なら件数は表示しない。
  final List<int>? counts;

  final int selected;

  /// true なら折り返して並べる（デザインシステムの Chip は flex-wrap・間隔 space-2）。
  final bool wrap;

  /// ダーク背景の画面では true（選択は blue、未選択は nightLineStrong の枠と明るい文字）。
  final bool dark;

  /// チップが載る面の色（右端のぼかしに使う）。
  final Color idleColor;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    if (wrap) {
      return Wrap(
        spacing: r.x(AppSpace.s2),
        runSpacing: r.y(AppSpace.s2),
        children: [for (var i = 0; i < labels.length; i++) _chip(r, i)],
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.y(AppSpace.s2)),
      child: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // 右端の余白：最後のボタンがぼかしに隠れないようにする。
            padding: EdgeInsets.only(right: r.x(AppSpace.s8)),
            child: Row(
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  if (i > 0) SizedBox(width: r.x(AppSpace.s2)),
                  _chip(r, i),
                ],
              ],
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: r.x(AppSpace.s8),
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [idleColor.withValues(alpha: 0), idleColor],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(Responsive r, int i) {
    final on = i == selected;
    final n = counts != null && i < counts!.length ? counts![i] : null;
    final text = '${on ? '✓ ' : ''}${labels[i]}${n == null ? '' : ' $n'}';
    return Semantics(
      button: true,
      selected: on,
      label: n == null ? labels[i] : '${labels[i]} $n件',
      child: GestureDetector(
        onTap: () => onChanged?.call(i),
        child: Container(
          height: r.y(44),
          constraints: BoxConstraints(minWidth: r.x(80)),
          padding: EdgeInsets.symmetric(horizontal: r.x(AppSpace.s4)),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.transparent,
            // 選択中は brand の2px枠。未選択は line-strong の細い枠。語句「✓」も添える。
            border: Border.all(
                color: on
                    ? AppColors.blue
                    : (dark
                        ? AppColors.white.withValues(alpha: 0.55)
                        : AppColors.ink.withValues(alpha: 0.55)),
                width: on ? 2 : 1),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: ExcludeSemantics(
            child: Text(
              text,
              style: AppText.body(r,
                  color: on
                      ? AppColors.blue
                      : (dark ? AppColors.white : AppColors.ink),
                  weight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
