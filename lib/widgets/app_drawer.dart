import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import '../core/app_colors.dart';
import '../core/part_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/request_status.dart';
import '../domain/staff_access.dart';
import 'app_icon.dart';
import 'confirm_logout.dart';
import 'ruby_text.dart';

/// NotoSansJP で、行の下の端から日本語の字の下の端までの高さ（文字の大きさに対する割合）。
/// 行の高さが 1.5 のときの値。アイコンと文字を下でそろえるときに使う。
const _glyphBottom = 0.218;

/// 行の高さが 1.0 の名前で、日本語の字が枠の下へ出る分（文字の大きさに対する割合）。
const _glyphOverhang = 0.047;

/// 左から出るドロワー（Figma 421:846）。幅は 354/390、画面の高さいっぱい。
/// ink→amber（アップバー下端の線の色）の縦グラデーションの面に、ロゴ・項目・区切り線・名前とログアウトのアイコン・バージョンを縦に並べる。
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  /// 遷移先と立場の選び方は、メイン画面のメニュー（MenuScreen）と同じ。
  /// メイン画面を土台に残して、選んだ画面へ進む。
  void _open(BuildContext context, UserRole? mode, String route) {
    if (mode != null) Services.repo.staffMode = mode;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(route, (r) => r.settings.name == '/menu');
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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // 画面の背景色から、アップバー下端の線の色（amber）へ。
            colors: [AppColors.ink, AppColors.amber],
          ),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.16)),
        ),
        // 画面が低い・文字が大きいときは、中身がスクロールし、ログアウトまで操作できる。
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Clip Desk',
                        style: AppText.noto(r.x(24),
                            color: AppColors.white, height: 32 / 24)),
                    SizedBox(height: r.y(20)),
                    // メイン画面のメニューと同じ項目・同じ出し分け（権限）・同じ遷移先。
                    StreamBuilder<StaffAccess>(
                      stream:
                          uid == null ? null : Services.repo.watchAccess(uid),
                      builder: (context, snap) {
                        final a = snap.data ?? StaffAccess.none;
                        return Column(children: [
                          if (a.canRequest)
                            _Tile(
                                AppIcon(AppIcons.addCircle,
                                    size: r.x(24), color: AppColors.white),
                                '依頼する',
                                () => _open(
                                    context, UserRole.requester, '/chat')),
                          if (a.canRequest || a.canEdit)
                            _Tile(
                                AppIcon(AppIcons.viewCozy,
                                    size: r.x(24), color: AppColors.white),
                                'ダッシュボード',
                                () => _open(
                                    context,
                                    a.canEdit
                                        ? UserRole.editor
                                        : UserRole.requester,
                                    '/home')),
                          if (a.canRequest || a.canEdit)
                            _Tile(
                                AppIcon(AppIcons.notificationsFill,
                                    size: r.x(24), color: AppColors.white),
                                '通知',
                                () => _open(context, null, '/notifications')),
                          _Tile(
                              AppIcon(AppIcons.bookshelf,
                                  size: r.x(24), color: AppColors.white),
                              'ライブラリ',
                              () => _open(context, null, '/library')),
                          if (a.manager)
                            _Tile(
                                Icon(Icons.group_outlined,
                                    size: r.x(24), color: AppColors.white),
                                '登録スタッフ',
                                () => _open(context, null, '/staff')),
                          _Tile(
                              AppIcon(AppIcons.settings,
                                  size: r.x(24), color: AppColors.white),
                              '設定',
                              () => _open(context, null, '/settings')),
                        ]);
                      },
                    ),
                    const Spacer(),
                    // 区切り線の下に、ログイン中の名前とログアウトのアイコン、その下にバージョン。
                    // 線は、どの配色でも明るい色。
                    Divider(
                        color: AppColors.on(Colors.black),
                        height: 1,
                        thickness: 1),
                    SizedBox(height: r.y(4)),
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: r.x(56)),
                      child: Padding(
                        padding: EdgeInsets.only(top: r.y(5)),
                        child: Align(
                          alignment: Alignment.topCenter,
                          // 名前の字と、ログアウトのアイコンの絵（ボタンの下から12）の下の端をそろえる。
                          // 名前は行の高さが 1.0 で、字が枠より少し下へ出るので、その分も持ち上げる。
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                        bottom: r.x(12) +
                                            r.tx(24) * _glyphOverhang),
                                    child: _UserName(uid: uid),
                                  ),
                                ),
                                const _LogoutButton(),
                              ]),
                        ),
                      ),
                    ),
                    Text('Version 1.0.0',
                        style: AppText.noto(r.x(12),
                            weight: FontWeight.w400,
                            color: PartColors.drawerVersion,
                            height: 16 / 12)),
                  ],
                ),
              ),
            ),
          ),
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
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    final fallback = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : (user?.email ?? '');
    return FutureBuilder<String?>(
      future: uid == null ? Future.value(null) : Services.repo.userName(uid!),
      builder: (context, snap) {
        final name = snap.data ?? fallback;
        if (name.isEmpty) return const SizedBox.shrink();
        return Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.noto(r.x(24),
                color: PartColors.drawerFooter, height: 1));
      },
    );
  }
}

/// ログアウトのアイコンボタン。押すと確認のポップアップを出す。
class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return IconButton(
      tooltip: 'ログアウト',
      padding: EdgeInsets.zero,
      // パソコンのブラウザでもボタンが縮まないようにする（名前との下ぞろえがずれる）。
      visualDensity: VisualDensity.standard,
      constraints: BoxConstraints.tightFor(width: r.x(48), height: r.x(48)),
      alignment: Alignment.centerRight,
      onPressed: () => confirmAndLogout(context),
      // SVG は周りに余白がある（40 のうち絵は 30）。大きさ32で絵が24になり、右へ4ずらして端にそろえる。
      icon: Transform.translate(
        offset: Offset(r.x(4), 0),
        child: AppIcon(AppIcons.logout,
            size: r.x(32), color: PartColors.drawerFooter),
      ),
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
          // アイコンは、文字の下の端にそろえる（ふりがなで行が高くなっても、本文の横に並ぶ）。
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // アイコンの絵は下に3ほどの余白があるので、文字の大きさに合わせて持ち上げる。
            Padding(
              padding: EdgeInsets.only(
                  bottom: math.max(0, r.tx(16) * _glyphBottom - r.x(3))),
              child: icon,
            ),
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
