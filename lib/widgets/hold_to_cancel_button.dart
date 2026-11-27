import 'package:flutter/material.dart' hide Text;

import '../core/app_colors.dart';
import '../core/part_colors.dart';
import '../core/app_text.dart';
import '../core/app_tokens.dart';
import '../core/responsive.dart';
import 'hold_to_confirm.dart';
import 'ruby_text.dart';

/// 「依頼取消」ボタン。長押しで取り消す（確認ダイアログは出さない。動きは [HoldToConfirm]）。
/// ボタンの中には文字だけを置く。
class HoldToCancelButton extends StatelessWidget {
  const HoldToCancelButton({
    super.key,
    required this.onConfirmed,
    this.busy = false,
    this.duration = HoldToConfirm.defaultDuration,
  });

  /// 長押しが完了したとき。
  final VoidCallback onConfirmed;

  /// 処理中は押せない。
  final bool busy;

  /// 1周するまでの長押しの時間。
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final radius = BorderRadius.circular(AppRadius.md);
    final seconds = duration.inSeconds;
    return Semantics(
      button: true,
      label: '依頼取消（$seconds秒間、長押しで取り消します）',
      child: Tooltip(
        message: '$seconds秒間、長押しで依頼を取り消します',
        child: Material(
          color:
              busy ? AppColors.white.withValues(alpha: 0.16) : AppColors.amber,
          borderRadius: radius,
          child: HoldToConfirm(
            onConfirmed: onConfirmed,
            busy: busy,
            duration: duration,
            popupMessage: 'このまま押し続けると\n依頼を取り消します',
            shortPressMessage: '$seconds秒間、長押しすると依頼を取り消します',
            child: SizedBox(
              height: r.x(48),
              width: double.infinity,
              child: Center(
                child: Text('依頼取消',
                    maxLines: 1,
                    style: AppText.noto(r.x(14), color: PartColors.onAmber)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
