import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/request_status.dart';
import 'app_icon.dart';
import 'unread_builder.dart';

/// 左から出るドロワー（Figma 291:504）。幅は 354/390、画面の高さいっぱい。
/// ink→brand の縦グラデーションの面に、ロゴ・項目・区切り線・ログアウト・バージョンを縦に並べる。
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _go(BuildContext context, String route) {
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final uid = Services.uid;
    return Drawer(
      width: r.x(354),
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      child: Container(
        padding: EdgeInsets.fromLTRB(r.x(16), r.y(48), r.x(16), r.y(24)),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.ink, AppColors.blue],
          ),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Clip Desk',
                style: AppText.noto(r.x(24),
                    color: AppColors.white, height: 32 / 24)),
            SizedBox(height: r.y(20)),
            _Tile(AppIcons.menu, 'メイン', () => _go(context, '/menu')),
            _Tile(AppIcons.viewCozy, 'ホーム', () => _go(context, '/home')),
            StreamBuilder<UserRole?>(
              stream: uid == null ? null : Services.repo.watchRole(uid),
              builder: (context, snap) => snap.data == UserRole.requester
                  ? _Tile(
                      AppIcons.addCircle, '新規依頼', () => _go(context, '/chat'))
                  : const SizedBox.shrink(),
            ),
            _NotificationTile(
                onTap: () => _go(context, '/notifications'), uid: uid),
            _Tile(AppIcons.systemUpdateAlt, '納品ライブラリ',
                () => _go(context, '/library')),
            // 設定画面はまだないため、押すとドロワーを閉じるだけ。
            _Tile(AppIcons.settings, '設定', () => Navigator.of(context).pop()),
            const Spacer(),
            Divider(
                color: AppColors.white.withValues(alpha: 0.16),
                height: 1,
                thickness: 1),
            _Tile(AppIcons.logout, 'ログアウト', () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) _go(context, '/');
            }),
            SizedBox(height: r.y(4)),
            Text('Version 1.0.0',
                style: AppText.noto(r.x(12),
                    weight: FontWeight.w400,
                    color: AppColors.white.withValues(alpha: 0.7),
                    height: 16 / 12)),
          ],
        ),
      ),
    );
  }
}

/// 「通知」：未読があれば、右端に琥珀色の件数バッジを付ける。
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.onTap, required this.uid});

  final VoidCallback onTap;
  final String? uid;

  @override
  Widget build(BuildContext context) {
    Widget tile(int unread) => _Tile(AppIcons.notifications, '通知', onTap,
        badge: unread > 0 ? unread : null);
    if (uid == null) return tile(0);
    return StreamBuilder<UserRole?>(
      stream: Services.repo.watchRole(uid!),
      builder: (context, role) => role.data == null
          ? tile(0)
          : UnreadBuilder(
              uid: uid!,
              role: role.data!,
              builder: (context, all, unread) => tile(unread.length)),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.label, this.onTap, {this.badge});

  final AppIcons icon;
  final String label;
  final VoidCallback? onTap;

  /// 右端の件数バッジ。null なら出さない。
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: r.y(12)),
        child: Row(
          children: [
            AppIcon(icon, size: r.x(24), color: AppColors.white),
            SizedBox(width: r.x(14)),
            Expanded(
              child: Text(label,
                  style: AppText.noto(r.x(16),
                      color: AppColors.white, height: 24 / 16)),
            ),
            if (badge != null)
              Container(
                width: r.x(24),
                height: r.x(24),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: AppColors.amber, shape: BoxShape.circle),
                child: Text('$badge',
                    semanticsLabel: '未読$badge件',
                    style: AppText.noto(r.x(12),
                        color: AppColors.ink, height: 16 / 12)),
              ),
          ],
        ),
      ),
    );
  }
}
