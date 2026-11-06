import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';

/// 左から出る青いドロワー。幅は画面の 350/390。
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _go(BuildContext context, String route) {
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Drawer(
      width: r.x(350),
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.fromLTRB(r.x(10), r.y(10), r.x(10), 0),
          child: Container(
            height: r.y(434),
            padding: EdgeInsets.symmetric(vertical: r.y(16)),
            decoration: BoxDecoration(
              color: AppColors.blue,
              border: Border.all(color: AppColors.ink),
              borderRadius: BorderRadius.circular(r.x(16)),
            ),
            child: Column(
              children: [
                _Tile(Icons.home_outlined, 'ホーム', () => _go(context, '/home')),
                _Tile(Icons.add_circle_outline, '新しい依頼',
                    () => _go(context, '/chat')),
                _Tile(Icons.video_library_outlined, '納品ライブラリ',
                    () => Navigator.of(context).pop()),
                _Tile(Icons.settings, '設定', () => Navigator.of(context).pop()),
                const Spacer(),
                _Tile(Icons.logout, 'ログアウト', () => _go(context, '/')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: r.y(56),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: r.x(16)),
          child: Row(
            children: [
              SizedBox(
                width: r.x(40),
                child: Icon(icon, size: r.x(24), color: Colors.white),
              ),
              Text(
                label,
                style: AppText.noto(r.x(16),
                    color: Colors.white, height: 20.8 / 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
