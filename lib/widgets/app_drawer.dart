import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/request_status.dart';

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
            height: r.y(490),
            padding: EdgeInsets.symmetric(vertical: r.y(16)),
            decoration: BoxDecoration(
              color: AppColors.blue,
              border: Border.all(color: AppColors.ink),
              borderRadius: BorderRadius.circular(r.x(16)),
            ),
            child: Column(
              children: [
                _Tile(Icons.apps, 'メイン', () => _go(context, '/menu')),
                _Tile(Icons.home_outlined, 'ホーム', () => _go(context, '/home')),
                StreamBuilder<UserRole?>(
                  stream: Services.uid == null
                      ? null
                      : Services.repo.watchRole(Services.uid!),
                  builder: (context, snap) => snap.data == UserRole.requester
                      ? _Tile(Icons.add_circle_outline, '新しい依頼',
                          () => _go(context, '/chat'))
                      : const SizedBox.shrink(),
                ),
                _Tile(Icons.notifications_none, '通知',
                    () => _go(context, '/notifications')),
                _Tile(Icons.video_library_outlined, '納品ライブラリ',
                    () => _go(context, '/library')),
                const Spacer(),
                _Tile(Icons.logout, 'ログアウト', () async {
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
