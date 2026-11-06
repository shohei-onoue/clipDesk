import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';

/// 「すべて / 編集中 / 確認中 / 公開済」の絞り込みボタン。
class FilterChipsRow extends StatelessWidget {
  const FilterChipsRow({
    super.key,
    this.selected = 0,
    this.idleColor = Colors.white,
    this.selectedTextColor = Colors.white,
    this.onChanged,
  });

  static const _labels = ['すべて', '編集中', '確認中', '公開済'];

  final int selected;
  final Color idleColor;
  final Color selectedTextColor;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.y(10)),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            if (i > 0) SizedBox(width: r.x(8)),
            Expanded(child: _chip(r, i)),
          ],
        ],
      ),
    );
  }

  Widget _chip(Responsive r, int i) {
    final on = i == selected;
    return GestureDetector(
      onTap: () => onChanged?.call(i),
      child: Container(
        height: r.y(44),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.blue : idleColor,
          border: Border.all(color: AppColors.ink, width: on ? 3 : 1),
          borderRadius: BorderRadius.circular(r.x(16)),
        ),
        child: Text(
          on ? '✓ ${_labels[i]}' : _labels[i],
          style: AppText.noto(
            r.x(15),
            color: on ? selectedTextColor : AppColors.ink,
            height: 19.5 / 15,
          ),
        ),
      ),
    );
  }
}
