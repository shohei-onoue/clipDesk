import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';

enum StepState { done, current, pending }

/// 「進捗確認カード」: 依頼名 + 5つの工程ステップ。
class StepProgressCard extends StatelessWidget {
  const StepProgressCard({super.key, required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;

  static const _steps = [
    ('新規依頼', StepState.done),
    ('編集中', StepState.done),
    ('提出中', StepState.current),
    ('再編集', StepState.pending),
    ('完了', StepState.pending),
  ];

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: r.x(5), vertical: r.y(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.blue, width: 2),
          borderRadius: BorderRadius.circular(r.x(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.noto(r.x(20), height: 1.5)),
            SizedBox(height: r.y(10)),
            Row(
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  if (i > 0) SizedBox(width: r.x(8)),
                  Expanded(
                    flex: _steps[i].$2 == StepState.current ? 69 : 65,
                    child: _Step(label: _steps[i].$1, state: _steps[i].$2),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.state});

  final String label;
  final StepState state;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final done = state == StepState.done;
    final current = state == StepState.current;

    final top = done ? '✓' : (current ? '現在' : '未到達');
    final topColor = done
        ? Colors.white
        : (current ? AppColors.blue : AppColors.stepGrey);
    final bottomColor = done ? Colors.white : AppColors.ink;

    return Container(
      height: r.y(57),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? AppColors.blue : Colors.white,
        border: Border.all(
          color: current ? AppColors.blue : AppColors.stepBorder,
          width: current ? 3 : 1,
        ),
        borderRadius: BorderRadius.circular(r.x(6)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(top, style: AppText.noto(r.x(14), color: topColor, height: 1.5)),
            SizedBox(height: r.y(4)),
            Text(label,
                style: AppText.noto(r.x(14), color: bottomColor, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
