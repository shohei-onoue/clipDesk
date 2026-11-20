import 'package:flutter/material.dart' hide Text;

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import 'ruby_text.dart';

/// スワイプで現れるボタン1つ分。
class SwipeAction {
  const SwipeAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

/// 左にスワイプすると、右端からボタン（編集・削除など）が現れる（Behind motion）。
/// 途中で離すと、半分を超えていれば開き、超えていなければ閉じる（アニメーションで動く）。
/// 開いているときにカードをタップすると閉じる。ボタンを押すと閉じてから実行する。
/// 別のカードをスワイプし始めると、開いていたカードは閉じる（開くのは常に1枚だけ）。
class SwipeActions extends StatefulWidget {
  const SwipeActions({super.key, required this.child, required this.actions});
  final Widget child;
  final List<SwipeAction> actions;

  @override
  State<SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<SwipeActions>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220));
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  /// いま操作中（開いている）カード。別のカードを動かし始めたら閉じる。
  static _SwipeActionsState? _active;

  @override
  void dispose() {
    if (_active == this) _active = null;
    _c.dispose();
    super.dispose();
  }

  void _settle({double? velocity}) {
    final open = (velocity != null && velocity.abs() > 300)
        ? velocity < 0
        : _c.value > 0.5;
    _c.animateTo(open ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final one = r.x(80);
    final gap = r.x(4);
    // 開いたときに動く幅：ボタン全部と、ボタン同士・カードとの隙間。
    final width = one * widget.actions.length + gap * widget.actions.length;
    return GestureDetector(
      onHorizontalDragStart: (_) {
        if (_active != this) _active?._c.animateTo(0);
        _active = this;
      },
      onHorizontalDragUpdate: (d) =>
          _c.value = (_c.value - d.delta.dx / width).clamp(0.0, 1.0),
      onHorizontalDragEnd: (d) => _settle(velocity: d.primaryVelocity),
      child: Stack(children: [
        // 後ろにあるボタン。ボタンは動かず、カードが左へ滑って空いた分だけ見える。
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: AnimatedBuilder(
              animation: _t,
              builder: (_, child) => ClipRect(
                child: Align(
                    alignment: Alignment.centerRight,
                    widthFactor: _t.value,
                    child: child),
              ),
              // 高さは、後ろの Stack（カードの高さ）いっぱいにそろえる。
              child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final a in widget.actions)
                      Semantics(
                        button: true,
                        label: a.label,
                        child: GestureDetector(
                          onTap: () {
                            _c.animateTo(0);
                            a.onTap();
                          },
                          child: Container(
                            width: one,
                            margin: EdgeInsets.only(left: gap),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: a.color,
                              borderRadius: BorderRadius.circular(r.x(15)),
                            ),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(a.icon,
                                      color: AppColors.onDark, size: r.x(26)),
                                  Text(a.label,
                                      style: AppText.dark(r.x(12),
                                          color: AppColors.onDark)),
                                ]),
                          ),
                        ),
                      ),
                  ]),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _t,
          builder: (_, child) => Transform.translate(
              offset: Offset(-width * _t.value, 0), child: child),
          // 開いているときは、カードのタップは閉じるだけ。
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, child) => GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _c.value > 0.05 ? () => _c.animateTo(0) : null,
              child: IgnorePointer(ignoring: _c.value > 0.05, child: child),
            ),
            child: widget.child,
          ),
        ),
      ]),
    );
  }
}
