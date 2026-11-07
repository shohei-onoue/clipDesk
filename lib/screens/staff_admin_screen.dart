import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../data/request_repository.dart';
import '../data/services.dart';
import '../domain/staff_access.dart';
import '../widgets/app_header.dart';

/// スタッフ承認（責任者のみ）。新規登録したアカウントに権限を割り当てる。
/// 権限：編集者／依頼者／両方。責任者の印は別に付けられる。承認の取り消しもできる。
/// 自分自身の権限は変更できない（ルールでも拒否される）。
class StaffAdminScreen extends StatelessWidget {
  const StaffAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final me = Services.uid;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          const AppHeader(title: 'スタッフ承認', background: AppColors.bg),
          Expanded(
            child: me == null
                ? const Center(child: Text('ログインしてください'))
                : StreamBuilder<StaffAccess>(
                    stream: Services.repo.watchAccess(me),
                    builder: (context, access) {
                      if (!(access.data?.manager ?? false)) {
                        return Center(
                            child: Text(access.connectionState ==
                                    ConnectionState.waiting
                                ? ''
                                : 'この画面は責任者だけが使えます'));
                      }
                      return StreamBuilder<List<StaffUser>>(
                        stream: Services.repo.watchUsers(),
                        builder: (context, users) {
                          if (users.hasError) {
                            return Center(
                                child: Text('読み込みに失敗しました：${users.error}'));
                          }
                          final list = [...?users.data]
                            ..sort((a, b) => a.email.compareTo(b.email));
                          return ListView(
                            padding: EdgeInsets.all(r.x(10)),
                            children: [
                              for (final u in list)
                                if (u.uid != me) _UserTile(user: u),
                              if (list.length <= 1 && users.hasData)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('ほかの登録アカウントはありません'),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

class _UserTile extends StatefulWidget {
  const _UserTile({required this.user});
  final StaffUser user;

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  bool _busy = false;

  Future<void> _save(
      {required bool canRequest,
      required bool canEdit,
      required bool manager}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Services.repo.setStaffAccess(widget.user.uid,
          canRequest: canRequest, canEdit: canEdit, manager: manager);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('変更できませんでした：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final u = widget.user;
    return StreamBuilder<StaffAccess>(
      stream: Services.repo.watchAccess(u.uid),
      builder: (context, snap) {
        final a = snap.data ?? StaffAccess.none;
        return Container(
          margin: EdgeInsets.only(bottom: r.y(10)),
          padding: EdgeInsets.all(r.x(14)),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
                color: a.approved ? AppColors.ink : AppColors.amber,
                width: a.approved ? 1 : 3),
            borderRadius: BorderRadius.circular(r.x(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(u.name.isEmpty ? '（名前なし）' : u.name,
                  style: AppText.noto(r.x(16))),
              Text(u.email,
                  style: AppText.noto(r.x(13), color: AppColors.stepGrey)),
              SizedBox(height: r.y(6)),
              Text('現在：${a.label}${a.manager ? '　責任者' : ''}',
                  style: AppText.noto(r.x(13), weight: FontWeight.w500)),
              Wrap(spacing: 8, children: [
                for (final o in const [
                  ('編集者', false, true),
                  ('依頼者', true, false),
                  ('両方', true, true),
                ])
                  ChoiceChip(
                    label: Text(o.$1),
                    selected: a.canRequest == o.$2 && a.canEdit == o.$3,
                    onSelected: _busy
                        ? null
                        : (_) => _save(
                            canRequest: o.$2,
                            canEdit: o.$3,
                            manager: a.manager),
                  ),
              ]),
              if (a.approved)
                Row(children: [
                  Expanded(
                    child: SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('責任者にする'),
                      value: a.manager,
                      onChanged: _busy
                          ? null
                          : (v) => _save(
                              canRequest: a.canRequest,
                              canEdit: a.canEdit,
                              manager: v),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _save(
                            canRequest: false, canEdit: false, manager: false),
                    child: const Text('承認を取り消す'),
                  ),
                ]),
            ],
          ),
        );
      },
    );
  }
}
