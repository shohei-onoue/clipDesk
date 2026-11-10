import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';

/// 権限のカード（「編集者」「依頼者」「管理者権限」）。スタッフカード、編集ダイアログ、招待画面で共有する。
/// 選択中は blue 塗り＋White文字、未選択は枠だけ。[onChanged] を渡すと押して切り替えられる
/// （渡さないと表示だけ）。
class RoleChip extends StatelessWidget {
  const RoleChip(this.label,
      {super.key, required this.selected, this.onChanged});

  final String label;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final box = Container(
      height: r.x(32),
      padding: EdgeInsets.symmetric(horizontal: r.x(12)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.blue : null,
        border: selected
            ? null
            : Border.all(color: AppColors.white.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(r.x(8)),
      ),
      child: Text(label,
          style: AppText.dark(r.x(14),
              color: selected
                  ? AppColors.white
                  : AppColors.white.withValues(alpha: 0.7))),
    );
    return Semantics(
      button: onChanged != null,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: onChanged == null
            ? box
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged!(!selected),
                child: box,
              ),
      ),
    );
  }
}
