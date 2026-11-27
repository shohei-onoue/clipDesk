import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_tokens.dart';
import 'ruby_text.dart';

/// 取り消し・削除などの長押し操作（確認ダイアログは出さない）。
/// [child] を押している間、画面の中心に出るドーナツグラフが12時の位置から時計回りに塗りつぶされ、
/// 1周（12時に戻る）したら [onConfirmed] を呼ぶ。途中で離したり指を動かしたりすると、
/// 塗りは戻り、実行しない。ポップアップには、残り秒数と [popupMessage] を出す。
class HoldToConfirm extends StatefulWidget {
  const HoldToConfirm({
    super.key,
    required this.onConfirmed,
    required this.popupMessage,
    required this.shortPressMessage,
    required this.child,
    this.busy = false,
    this.duration = defaultDuration,
  });

  /// 長押しの時間の標準。
  static const defaultDuration = Duration(seconds: 5);

  /// 長押しが完了したとき。
  final VoidCallback onConfirmed;

  /// 押している間、ポップアップに出す説明。
  final String popupMessage;

  /// 短く押しただけのときの案内。
  final String shortPressMessage;

  /// 押す部分の見た目。
  final Widget child;

  /// 処理中は押せない。
  final bool busy;

  /// 1周するまでの長押しの時間。
  final Duration duration;

  @override
  State<HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends State<HoldToConfirm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) {
            HapticFeedback.mediumImpact();
            _pointer = null;
            _hidePopup();
            widget.onConfirmed();
            // 実行が始まったら、塗りを戻しておく（失敗して画面に残っても、もう一度押せる）。
            if (mounted) _c.value = 0;
          }
        });

  /// 押している指。2本目の指は数えない。
  int? _pointer;
  Offset _downPosition = Offset.zero;
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
          child: _HoldPopup(
              animation: _c,
              duration: widget.duration,
              message: widget.popupMessage),
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

  void _down(PointerDownEvent e) {
    if (widget.busy || _pointer != null) return;
    _pointer = e.pointer;
    _downPosition = e.position;
    _downAt = DateTime.now();
    _showPopup();
    _c.forward(from: 0);
  }

  /// 指が動いたら、画面のスクロールやスライドのつもりなので、やめる。
  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    if ((e.position - _downPosition).distance <= kTouchSlop) return;
    _downAt = null;
    _release();
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    final at = _downAt;
    _release();
    // 短く押しただけなら、長押しが必要なことを案内する。
    if (e is PointerUpEvent &&
        at != null &&
        DateTime.now().difference(at) < const Duration(milliseconds: 800) &&
        mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(widget.shortPressMessage)));
    }
  }

  /// 途中でやめる：塗りを戻す。
  void _release() {
    _pointer = null;
    _hidePopup();
    _c.value = 0;
  }

  @override
  Widget build(BuildContext context) => Listener(
        // 文字の外側（ボタンの余白）を押しても反応する。
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: widget.child,
      );
}

/// ドーナツグラフ（ポップアップで使う）。薄い輪の上に、12時から時計回りに [progress]（0〜1）だけ塗る。
class _DonutPainter extends CustomPainter {
  _DonutPainter(this.progress, this.color, {required this.baseColor});
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
  const _HoldPopup(
      {required this.animation, required this.duration, required this.message});
  final Animation<double> animation;
  final Duration duration;
  final String message;

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
          Text(message,
              textAlign: TextAlign.center,
              style: AppText.dark(14, weight: FontWeight.w400, height: 1.5)),
        ]),
      ),
    );
  }
}
