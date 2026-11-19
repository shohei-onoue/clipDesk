import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import 'app_icon.dart';

/// 画面上部のAppBar（ダークテイスト）。高さ61。背景は ink、下端だけ accent へ変わる線。
/// 左に戻る（前の画面へ。[leadingIcon] で差し替え可）、中央にタイトル、右に [actions] とハンバーガー（ドロワーを開く）を置く。
/// ホーム画面だけは [showSettings] で、ハンバーガーのかわりに設定（調整のアイコン。歯車は使わない）を置く。
/// ボタンは必ず左端・右端に寄せ、タイトルだけを中央にする。アイコンには label（tooltip）を付ける。
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.onMenu,
    this.showSettings = false,
    this.onSettings,
    this.actions = const [],
    this.leadingIcon,
    this.leadingTooltip,
    this.onLeading,
  });

  final String title;
  final VoidCallback? onMenu;

  /// ホーム画面用。右端をハンバーガーではなく設定（調整のアイコン）にする。
  final bool showSettings;

  /// 設定画面は予定のため、未接続の間は押しても何も起きない。
  final VoidCallback? onSettings;

  /// 右端（ハンバーガー・設定の手前）に並べるボタン。
  final List<Widget> actions;

  /// 左端のアイコン。省略すると「戻る」（戻れる画面のみ）。
  final AppIcons? leadingIcon;
  final String? leadingTooltip;
  final VoidCallback? onLeading;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final hasDrawer = Scaffold.maybeOf(context)?.hasDrawer ?? false;
    final canPop = Navigator.of(context).canPop();
    final showMenu = !showSettings && (hasDrawer || onMenu != null);
    final showLeading = leadingIcon != null || canPop;
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
                  tooltip: leadingTooltip ?? '戻る',
                  onPressed:
                      onLeading ?? () => Navigator.of(context).maybePop(),
                  icon: AppIcon(leadingIcon ?? AppIcons.back,
                      size: r.x(32), color: AppColors.white),
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
                if (showSettings)
                  _HeaderIcon(
                      icon: AppIcons.tune,
                      tooltip: '設定',
                      onTap: onSettings,
                      size: tap),
                if (showMenu)
                  _HeaderIcon(
                    icon: AppIcons.menu,
                    tooltip: 'メニューを開く',
                    size: tap,
                    onTap:
                        onMenu ?? () => Scaffold.maybeOf(context)?.openDrawer(),
                  ),
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
