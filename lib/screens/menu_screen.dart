import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/request_status.dart';
import '../domain/staff_access.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/role_builder.dart';

/// ログイン後のメイン画面。「依頼する」「編集する」「進捗状況をみる」から各画面へ進む。
/// ボタンは付与された権限に応じて出す（依頼者／編集者／両方、責任者はスタッフ承認も）。暫定仕様（FigJamで未確定）。
/// 選んだ立場は [RequestRepository.staffMode] に保持し、roles/{uid} が 'staff' のとき使う。
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  void _go(BuildContext context, UserRole? mode, String route) {
    if (mode != null) Services.repo.staffMode = mode;
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'メイン', background: AppColors.bg),
            Expanded(
              child: RoleBuilder(
                builder: (context, uid, role) => StreamBuilder<StaffAccess>(
                  stream: Services.repo.watchAccess(uid),
                  builder: (context, snap) {
                    final a = snap.data ?? StaffAccess.none;
                    return ListView(
                      padding: EdgeInsets.all(r.x(16)),
                      children: [
                        if (a.canRequest)
                          _MenuButton(
                            icon: Icons.note_add_outlined,
                            title: '依頼する',
                            sub: '新しい依頼を出す・届いた動画を確認する',
                            onTap: () =>
                                _go(context, UserRole.requester, '/home'),
                          ),
                        if (a.canEdit)
                          _MenuButton(
                            icon: Icons.movie_edit,
                            title: '編集する',
                            sub: '依頼を受け付ける・動画を提出する',
                            onTap: () => _go(context, UserRole.editor, '/home'),
                          ),
                        _MenuButton(
                          icon: Icons.timeline,
                          title: '進捗状況をみる',
                          sub: '動いている案件を全員分見る',
                          onTap: () => _go(context, null, '/progress'),
                        ),
                        if (a.manager)
                          _MenuButton(
                            icon: Icons.group_add_outlined,
                            title: 'スタッフ承認',
                            sub: '新しく登録した人に権限を付ける',
                            onTap: () => _go(context, null, '/staff'),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.only(bottom: r.y(14)),
      child: Material(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(r.x(20)),
        child: InkWell(
          borderRadius: BorderRadius.circular(r.x(20)),
          onTap: onTap,
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: r.x(20), vertical: r.y(22)),
            child: Row(children: [
              Icon(icon, size: r.x(36), color: AppColors.bg),
              SizedBox(width: r.x(16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppText.noto(r.x(20), color: AppColors.bg)),
                    SizedBox(height: r.y(4)),
                    Text(sub,
                        style: AppText.noto(r.x(12), color: AppColors.bg)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: r.x(28), color: AppColors.bg),
            ]),
          ),
        ),
      ),
    );
  }
}
