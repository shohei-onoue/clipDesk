import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/request_status.dart';
import 'app_icon.dart';

/// 左から出るドロワー（ダークテイスト）。幅は画面の 350/390。ink→brand のグラデーションの面に、項目を縦に並べる。
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
            height: r.y(490),
            padding: EdgeInsets.symmetric(vertical: r.y(16)),
            decoration: BoxDecoration(
              // メイン画面のカードと同じ、ink から brand へ流れるグラデーション。
              gradient: const LinearGradient(
                begin: Alignment(-0.3, -1),
                end: Alignment(0.3, 1),
                colors: [
                  AppColors.ink,
                  AppColors.ink,
                  AppColors.blue,
                  AppColors.blue
                ],
                stops: [0, 0.6, 0.95, 1],
              ),
              border:
                  Border.all(color: AppColors.white.withValues(alpha: 0.16)),
              borderRadius: BorderRadius.circular(r.x(15)),
            ),
            child: Column(
              children: [
                _Tile(AppIcons.menu, 'メイン', () => _go(context, '/menu')),
                _Tile(AppIcons.viewCozy, 'ホーム', () => _go(context, '/home')),
                StreamBuilder<UserRole?>(
                  stream: Services.uid == null
                      ? null
                      : Services.repo.watchRole(Services.uid!),
                  builder: (context, snap) => snap.data == UserRole.requester
                      ? _Tile(AppIcons.addCircle, '新しい依頼',
                          () => _go(context, '/chat'))
                      : const SizedBox.shrink(),
                ),
                _Tile(AppIcons.notifications, '通知',
                    () => _go(context, '/notifications')),
                _Tile(AppIcons.systemUpdateAlt, '納品ライブラリ',
                    () => _go(context, '/library')),
                const Spacer(),
                Divider(
                    color: AppColors.white.withValues(alpha: 0.16),
                    height: r.y(1)),
                _Tile(AppIcons.logout, 'ログアウト', () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) _go(context, '/');
                }),
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

  final AppIcons icon;
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
                child: AppIcon(icon, size: r.x(28), color: AppColors.white),
              ),
              Text(
                label,
                style: AppText.noto(r.x(16),
                    weight: FontWeight.w400,
                    color: AppColors.white,
                    height: 20.8 / 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
