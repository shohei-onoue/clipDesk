import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/request_status.dart';
import 'app_icon.dart';

/// 下部バーのアイコンボタン1つ分。
class BarItem {
  const BarItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
    required this.route,
    this.size = 32,
    this.replaceToHome = false,
  });

  /// 読み上げ・tooltip 用の語句。
  final String label;
  final AppIcons icon;

  /// 選択中に使う塗りつぶし版。なければ [icon] のまま。
  final AppIcons? selectedIcon;

  /// 移動先。今いる画面と同じなら「選択中」（amber）になり、押しても移動しない。
  final String route;
  final double size;

  /// true なら、メイン画面まで戻ってから route を開く（ホーム用）。
  final bool replaceToHome;
}

/// 画面下部の共通バー（ダークテイスト）。背景は透明、高さ56、アイコンを等間隔に置く。
/// 未選択のアイコンは white、選択中（今表示している画面）は amber。
/// タップすると、バーの背面にエフェクト（広がって消える円）が出てから移動する。
/// アイコンは画面ごとに [items] で変えられる。省略時は役割に合わせた既定の3つ
/// （ホーム／新規依頼（編集者は進捗状況）／納品ライブラリ）。
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, this.items, this.homeRoute = '/home'});

  /// 「ホーム」ボタンの移動先（依頼者ページは '/requester'）。
  final String homeRoute;

  /// 画面ごとのアイコン。null なら既定。
  final List<BarItem>? items;

  static const _home = BarItem(
      label: 'ホーム',
      icon: AppIcons.viewCozy,
      route: '/home',
      replaceToHome: true);
  static const _library = BarItem(
      label: '納品ライブラリ', icon: AppIcons.systemUpdateAlt, route: '/library');
  static const _add = BarItem(
      label: '新規依頼',
      icon: AppIcons.addCircle,
      selectedIcon: AppIcons.addCircleFill,
      route: '/chat',
      size: 40);
  static const _progress = BarItem(
      label: '進捗状況',
      icon: AppIcons.calendarMonth,
      selectedIcon: AppIcons.calendarMonthFill,
      route: '/progress',
      size: 40);

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final uid = Services.uid;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: r.x(56),
        child: items != null
            ? _row(context, items!)
            : uid == null
                ? _row(context, _defaults(UserRole.requester))
                : StreamBuilder<UserRole?>(
                    stream: Services.repo.watchRole(uid),
                    builder: (context, snap) => _row(
                        context, _defaults(snap.data ?? UserRole.requester)),
                  ),
      ),
    );
  }

  List<BarItem> _defaults(UserRole role) => [
        BarItem(
            label: _home.label,
            icon: _home.icon,
            route: homeRoute,
            replaceToHome: true),
        role == UserRole.editor ? _progress : _add,
        _library
      ];

  Widget _row(BuildContext context, List<BarItem> list) {
    final here = ModalRoute.of(context)?.settings.name;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final it in list)
          _BarButton(
            item: it,
            selected: it.route == here,
            onTap: () async {
              if (it.route == here) return;
              final nav = Navigator.of(context);
              // 効果が見えるよう、少し待ってから移動する。
              await Future<void>.delayed(const Duration(milliseconds: 220));
              if (it.replaceToHome) {
                nav.pushNamedAndRemoveUntil(
                    it.route, (route) => route.settings.name == '/menu');
              } else {
                nav.pushNamed(it.route);
              }
            },
          ),
      ],
    );
  }
}

class _BarButton extends StatefulWidget {
  const _BarButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final BarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_BarButton> createState() => _BarButtonState();
}

class _BarButtonState extends State<_BarButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fx = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void dispose() {
    _fx.dispose();
    super.dispose();
  }

  void _tap() {
    _fx.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final tap = r.x(56);
    final color = widget.selected ? AppColors.amber : AppColors.white;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.item.label,
      child: Tooltip(
        message: widget.item.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _tap,
          child: SizedBox(
            width: tap,
            height: tap,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // 背面のエフェクト：円が広がりながら消える。
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _fx,
                      builder: (context, _) {
                        final t = Curves.easeOut.transform(_fx.value);
                        final active = _fx.isAnimating;
                        return Opacity(
                          opacity: active ? (1 - t) * 0.6 : 0,
                          child: Transform.scale(
                            scale: 0.4 + t * 1.2,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.blue,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                ExcludeSemantics(
                  child: AppIcon(
                      widget.selected
                          ? (widget.item.selectedIcon ?? widget.item.icon)
                          : widget.item.icon,
                      size: r.x(widget.item.size),
                      color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
