import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import 'app_icon.dart';

/// 画面上部のAppBar（ダークテイスト）。高さ61。背景は ink、下端だけ accent へ変わる線。
/// 左にハンバーガー（ドロワーがある画面）、ドロワーがなければ戻る。中央にタイトル、右に [actions] と設定（歯車）を置く。
/// ボタンは必ず左端・右端に寄せ、タイトルだけを中央にする。アイコンには label（tooltip）を付ける。
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.onMenu,
    this.onSettings,
    this.actions = const [],
    this.leadingIcon,
    this.leadingTooltip,
    this.onLeading,
  });

  final String title;
  final VoidCallback? onMenu;

  /// 設定画面は予定のため、未接続の間は押しても何も起きない。
  final VoidCallback? onSettings;

  /// 右端（設定の手前）に並べるボタン。
  final List<Widget> actions;

  /// 左端のアイコン。省略するとドロワーがあればハンバーガー、なければ「戻る」。
  final AppIcons? leadingIcon;
  final String? leadingTooltip;
  final VoidCallback? onLeading;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final hasDrawer = Scaffold.maybeOf(context)?.hasDrawer ?? false;
    final canPop = Navigator.of(context).canPop();
    final showMenu = leadingIcon == null && (hasDrawer || onMenu != null);
    final showLeading = leadingIcon != null || showMenu || canPop;
    final tap = r.x(48); // タップ領域
    return Container(
      height: r.x(61),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.ink, AppColors.ink, AppColors.amber],
          stops: [0, 0.92308, 1],
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: r.x(1)),
      child: Stack(
        children: [
          if (showLeading)
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: tap,
                height: tap,
                child: IconButton(
                  tooltip: leadingTooltip ?? (showMenu ? 'メニューを開く' : '戻る'),
                  onPressed: onLeading ??
                      (showMenu
                          ? (onMenu ??
                              () => Scaffold.maybeOf(context)?.openDrawer())
                          : () => Navigator.of(context).maybePop()),
                  icon: AppIcon(
                      leadingIcon ?? (showMenu ? AppIcons.menu : AppIcons.back),
                      size: r.x(32),
                      color: AppColors.white),
                ),
              ),
            ),
          Center(
            child: Padding(
              // ボタンと重ならないよう、左右に余白をとる。
              padding: EdgeInsets.symmetric(horizontal: tap * 2),
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.noto(r.x(24),
                      weight: FontWeight.w400, color: AppColors.white)),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...actions,
                _HeaderIcon(
                    icon: AppIcons.settings,
                    tooltip: '設定',
                    onTap: onSettings,
                    size: tap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.size,
    this.onTap,
  });

  final AppIcons icon;
  final String tooltip;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: AppIcon(icon, size: r.x(32), color: AppColors.white),
      ),
    );
  }
}
