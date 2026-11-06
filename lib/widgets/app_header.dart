import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';

/// 画面上部のヘッダー（メニュー / タイトル / 設定）。
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.background = Colors.white,
    this.titleSize = 24,
    this.onMenu,
    this.onSettings,
  });

  final String title;
  final Color background;
  final double titleSize;
  final VoidCallback? onMenu;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      height: r.y(50),
      color: background,
      child: Row(
        children: [
          SizedBox(width: r.x(12)),
          _HeaderIcon(
            icon: Icons.menu,
            onTap: onMenu ?? () => Scaffold.maybeOf(context)?.openDrawer(),
          ),
          SizedBox(width: r.x(16)),
          Text(
            title,
            style: AppText.noto(r.x(titleSize), height: 32 / titleSize),
          ),
          const Spacer(),
          _HeaderIcon(icon: Icons.settings, onTap: onSettings),
          SizedBox(width: r.x(8)),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return InkResponse(
      onTap: onTap,
      child: SizedBox(
        width: r.x(48),
        height: r.x(48),
        child: Icon(icon, size: r.x(30), color: AppColors.ink),
      ),
    );
  }
}
