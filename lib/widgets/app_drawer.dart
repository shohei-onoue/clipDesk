import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/request_status.dart';
import '../domain/staff_access.dart';
import 'app_icon.dart';

/// 左から出るドロワー（Figma 291:504）。幅は 354/390、画面の高さいっぱい。
/// ink→brand の縦グラデーションの面に、ロゴ・項目・区切り線・ログアウト・バージョンを縦に並べる。
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  /// 遷移先と立場の選び方は、メイン画面のメニュー（MenuScreen）と同じ。
  /// メイン画面を土台に残して、選んだ画面へ進む。
  void _open(BuildContext context, UserRole? mode, String route) {
    if (mode != null) Services.repo.staffMode = mode;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(route, (r) => r.settings.name == '/menu');
  }

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
            // メイン画面のメニューと同じ項目・同じ出し分け（権限）・同じ遷移先。
            StreamBuilder<StaffAccess>(
              stream: uid == null ? null : Services.repo.watchAccess(uid),
              builder: (context, snap) {
                final a = snap.data ?? StaffAccess.none;
                return Column(children: [
                  if (a.canRequest)
                    _Tile(
                        AppIcon(AppIcons.addCircle,
                            size: r.x(24), color: AppColors.white),
                        '依頼する',
                        () => _open(context, UserRole.requester, '/chat')),
                  if (a.canRequest || a.canEdit)
                    _Tile(
                        AppIcon(AppIcons.viewCozy,
                            size: r.x(24), color: AppColors.white),
                        'ダッシュボード',
                        () => _open(
                            context,
                            a.canEdit ? UserRole.editor : UserRole.requester,
                            '/home')),
                  if (a.canRequest || a.canEdit)
                    _Tile(
                        AppIcon(AppIcons.notificationsFill,
                            size: r.x(24), color: AppColors.white),
                        '通知',
                        () => _open(context, null, '/notifications')),
                  _Tile(
                      AppIcon(AppIcons.systemUpdateAlt,
                          size: r.x(24), color: AppColors.white),
                      'ライブラリ',
                      () => _open(context, null, '/library')),
                  if (a.manager)
                    _Tile(
                        Icon(Icons.group_outlined,
                            size: r.x(24), color: AppColors.white),
                        '登録スタッフ',
                        () => _open(context, null, '/staff')),
                ]);
              },
            ),
            const Spacer(),
            // ログインしているユーザーの名前（users の name。なければ表示名、メールの順）。
            _UserName(uid: uid),
            Divider(
                color: AppColors.white.withValues(alpha: 0.16),
                height: 1,
                thickness: 1),
            _Tile(
                AppIcon(AppIcons.logout, size: r.x(24), color: AppColors.white),
                'ログアウト', () async {
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

class _UserName extends StatelessWidget {
  const _UserName({required this.uid});
  final String? uid;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final user = FirebaseAuth.instance.currentUser;
    final fallback = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : (user?.email ?? '');
    return FutureBuilder<String?>(
      future: uid == null ? Future.value(null) : Services.repo.userName(uid!),
      builder: (context, snap) {
        final name = snap.data ?? fallback;
        if (name.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(bottom: r.y(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ログイン中',
                  style: AppText.noto(r.x(12),
                      weight: FontWeight.w400,
                      color: AppColors.white.withValues(alpha: 0.7),
                      height: 16 / 12)),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.noto(r.x(16),
                      color: AppColors.white, height: 24 / 16)),
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.label, this.onTap);

  final Widget icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: r.y(12)),
        child: Row(
          children: [
            icon,
            SizedBox(width: r.x(14)),
            Expanded(
              child: Text(label,
                  style: AppText.noto(r.x(16),
                      color: AppColors.white, height: 24 / 16)),
            ),
          ],
        ),
      ),
    );
  }
}
