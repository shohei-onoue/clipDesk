import 'package:flutter/material.dart' hide Text;

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import 'ruby_text.dart';

// デザインシステム（docs/design-system/components.md）のホーム用部品：
// ホーム用部品：TopTabs。ダークテイスト。
// AppBar は AppHeader、下のバーは AppBottomBar を使う。

/// TopTabs：2〜3項目。選択中は brand の文字と4pxの下線、他は ink-muted。
class TopTabs extends StatelessWidget {
  const TopTabs({
    super.key,
    required this.items,
    required this.active,
    required this.onSelect,
  });

  final List<String> items;
  final int active;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(
            bottom: BorderSide(color: AppColors.white.withValues(alpha: 0.16))),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == active,
                label: items[i],
                child: InkWell(
                  onTap: () => onSelect(i),
                  child: ExcludeSemantics(
                    child: Container(
                      // 標準は高さ48。文字が大きい・ふりがなのときは、文字に合わせて広がる。
                      constraints: BoxConstraints(minHeight: r.y(48)),
                      padding:
                          EdgeInsets.symmetric(vertical: r.roomy ? r.x(6) : 0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                              color: i == active
                                  ? AppColors.blue
                                  : Colors.transparent,
                              width: 4),
                        ),
                      ),
                      child: Text(items[i],
                          style: AppText.body(r,
                              color: i == active
                                  ? AppColors.white
                                  : AppColors.white.withValues(alpha: 0.7),
                              weight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
