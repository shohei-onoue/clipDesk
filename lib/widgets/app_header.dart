import 'package:flutter/material.dart' hide Text;

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import 'app_icon.dart';
import 'ruby_text.dart';

/// 画面上部のAppBar（ダークテイスト）。高さ61。背景は ink、下端だけ accent へ変わる線。
/// 左に戻る（前の画面へ。[leadingIcon] で差し替え可）、中央にタイトル、右に [actions] とハンバーガー（ドロワーを開く）を置く。
/// 設定へはドロワーのメニューからのみ入る（ヘッダーには設定アイコンを置かない）。
/// ボタンは必ず左端・右端に寄せ、タイトルだけを中央にする。アイコンには label（tooltip）を付ける。
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.onMenu,
    this.actions = const [],
    this.leadingIcon,
    this.leadingTooltip,
    this.onLeading,
    this.alwaysBack = true,
  });

  final String title;
  final VoidCallback? onMenu;

  /// 右端（ハンバーガー・設定の手前）に並べるボタン。
  final List<Widget> actions;

  /// 左端のアイコン。省略すると「戻る」（戻れる画面のみ）。
  final AppIcons? leadingIcon;
  final String? leadingTooltip;
  final VoidCallback? onLeading;

  /// true のとき、戻れる画面が下に無くても戻るボタンを消さない（メイン画面へ戻る）。
  /// 画面の積み重なりが崩れた（ドロワーからの遷移・再読み込みなど）ときに、
  /// 戻るボタンが消えて行き場がなくなるのを防ぐ。ログイン前の登録画面だけ false。
  final bool alwaysBack;

  /// 左端ボタンの操作。次の2つの誤操作を防ぐ。
  /// - 戻る操作の途中（画面が閉じていく間）の二重タップ：2画面分戻ってしまう。
  /// - 画面が切り替わっている最中のタップ：戻った先の画面の同じ位置にある
  ///   ボタン（メイン画面ではログアウト）を、意図せず押してしまう。
  void _onLeading(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route != null) {
      if (!route.isCurrent) return;
      final moving = route.animation?.status != AnimationStatus.completed ||
          route.secondaryAnimation?.status != AnimationStatus.dismissed;
      if (moving) return;
    }
    if (onLeading != null) {
      onLeading!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // 戻り先が無いときは、メイン画面（/menu）へ。
      Navigator.of(context).pushNamedAndRemoveUntil('/menu', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final hasDrawer = Scaffold.maybeOf(context)?.hasDrawer ?? false;
    final canPop = Navigator.of(context).canPop();
    final showMenu = hasDrawer || onMenu != null;
    final showLeading = leadingIcon != null || canPop || alwaysBack;
    final tap = r.x(48); // タップ領域
    return Container(
      height: r.x(61),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bg, AppColors.bg, AppColors.amber],
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
                  onPressed: () => _onLeading(context),
                  icon: AppIcon(leadingIcon ?? AppIcons.back,
                      size: r.x(26), color: AppColors.white),
                ),
              ),
            ),
          Center(
            child: Padding(
              // ボタンと重ならないよう、左右に余白をとる。
              padding: EdgeInsets.symmetric(horizontal: tap * 2),
              // タイトルの文字の大きさは、設定（文字の大きさ）に関わらず標準で固定。
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
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
