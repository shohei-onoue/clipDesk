import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/part_colors.dart';
import '../core/app_text.dart';
import '../core/app_tokens.dart';
import '../core/responsive.dart';
import 'ruby_text.dart';

/// 「依頼取消」ボタン。長押しで取り消す（確認ダイアログは出さない）。
/// 押している間、画面の中心に出るドーナツグラフが12時の位置から時計回りに塗りつぶされ、
/// 1周（12時に戻る）したら [onConfirmed] を呼ぶ。途中で離すと、塗りは戻り、取り消さない。
/// ボタンの中には文字だけを置く。ポップアップには、残り秒数も出す。
class HoldToCancelButton extends StatefulWidget {
  const HoldToCancelButton({
    super.key,
    required this.onConfirmed,
    this.busy = false,
    this.duration = const Duration(seconds: 5),
  });

  /// 長押しが完了したとき。
  final VoidCallback onConfirmed;

  /// 処理中は押せない。
  final bool busy;

  /// 1周するまでの長押しの時間。
  final Duration duration;

  @override
  State<HoldToCancelButton> createState() => _HoldToCancelButtonState();
}

class _HoldToCancelButtonState extends State<HoldToCancelButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) {
            HapticFeedback.mediumImpact();
            _hidePopup();
            widget.onConfirmed();
            // 取り消しが始まったら、塗りを戻しておく（失敗して画面に残っても、もう一度押せる）。
            if (mounted) _c.value = 0;
          }
        });
  DateTime? _downAt;
  OverlayEntry? _popup;

  @override
  void dispose() {
    _hidePopup();
    _c.dispose();
    super.dispose();
  }

  void _showPopup() {
    if (_popup != null) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    // 押している指を邪魔しないよう、ポップアップは操作を受け付けない。
    _popup = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: Center(
          child: _HoldPopup(animation: _c, duration: widget.duration),
        ),
      ),
    );
    overlay.insert(_popup!);
  }

  void _hidePopup() {
    _popup?.remove();
    _popup?.dispose();
    _popup = null;
  }

  void _down() {
    if (widget.busy) return;
    _downAt = DateTime.now();
    _showPopup();
    _c.forward(from: 0);
  }

  void _up() {
    // 途中で離した：塗りを戻す。短く押しただけなら、長押しで取り消すことを案内する。
    _hidePopup();
    if (_c.status == AnimationStatus.completed) return;
    _c.value = 0;
    final at = _downAt;
    if (at != null &&
        DateTime.now().difference(at) < const Duration(milliseconds: 800) &&
        mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text('${widget.duration.inSeconds}秒間、長押しすると依頼を取り消します')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final radius = BorderRadius.circular(AppRadius.md);
    return Semantics(
      button: true,
      label: '依頼取消（${widget.duration.inSeconds}秒間、長押しで取り消します）',
      child: Tooltip(
        message: '${widget.duration.inSeconds}秒間、長押しで依頼を取り消します',
        child: Material(
          color: widget.busy
              ? AppColors.white.withValues(alpha: 0.16)
              : AppColors.amber,
          borderRadius: radius,
          child: Listener(
            onPointerDown: (_) => _down(),
            onPointerUp: (_) => _up(),
            onPointerCancel: (_) => _up(),
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

/// ドーナツグラフ（ポップアップで使う）。薄い輪の上に、12時から時計回りに [progress]（0〜1）だけ塗る。
class _DonutPainter extends CustomPainter {
  _DonutPainter(this.progress, this.color, {Color? baseColor})
      : baseColor = baseColor ?? color.withValues(alpha: 0.28);
  final double progress;
  final Color color;
  final Color baseColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.22;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = baseColor;
    canvas.drawArc(arc, 0, 6.2831853, false, base);
    if (progress <= 0) return;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color;
    // -π/2 が12時の位置。そこから時計回り。
    canvas.drawArc(arc, -1.5707963, 6.2831853 * progress, false, fill);
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.baseColor != baseColor;
}

/// 画面の中心に出す、押している間のポップアップ。大きなドーナツグラフと残り秒数。
class _HoldPopup extends StatelessWidget {
  const _HoldPopup({required this.animation, required this.duration});
  final Animation<double> animation;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ink,
      elevation: 12,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: 220,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.16)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: animation,
            builder: (_, __) {
              final left =
                  (duration.inMilliseconds * (1 - animation.value) / 1000)
                      .ceil()
                      .clamp(0, duration.inSeconds);
              return SizedBox(
                width: 140,
                height: 140,
                child: Stack(alignment: Alignment.center, children: [
                  CustomPaint(
                    size: const Size.square(140),
                    painter: _DonutPainter(animation.value, AppColors.amber,
                        baseColor: AppColors.white.withValues(alpha: 0.16)),
                  ),
                  Text('$left', style: AppText.dark(40)),
                ]),
              );
            },
          ),
          const SizedBox(height: 16),
          Text('このまま押し続けると\n依頼を取り消します',
              textAlign: TextAlign.center,
              style: AppText.dark(14, weight: FontWeight.w400, height: 1.5)),
        ]),
      ),
    );
  }
}
