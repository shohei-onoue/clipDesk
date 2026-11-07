import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';

/// 進捗などの絞り込みボタン。横にスクロールでき、右端が見切れる位置には
/// 薄いぼかしを重ねて「続きがある」ことを示す。[counts] があれば件数を添える。
class FilterChipsRow extends StatelessWidget {
  const FilterChipsRow({
    super.key,
    this.selected = 0,
    this.idleColor = Colors.white,
    this.selectedTextColor = Colors.white,
    this.onChanged,
    this.labels = defaultLabels,
    this.counts,
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
  final Color idleColor;
  final Color selectedTextColor;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.y(10)),
      child: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // 右端の余白：最後のボタンがぼかしに隠れないようにする。
            padding: EdgeInsets.only(right: r.x(36)),
            child: Row(
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  if (i > 0) SizedBox(width: r.x(8)),
                  _chip(r, i),
                ],
              ],
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: r.x(32),
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
          padding: EdgeInsets.symmetric(horizontal: r.x(14)),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.blue : idleColor,
            border: Border.all(color: AppColors.ink, width: on ? 3 : 1),
            borderRadius: BorderRadius.circular(r.x(16)),
          ),
          child: ExcludeSemantics(
            child: Text(
              text,
              style: AppText.noto(
                r.x(15),
                color: on ? selectedTextColor : AppColors.ink,
                height: 19.5 / 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
