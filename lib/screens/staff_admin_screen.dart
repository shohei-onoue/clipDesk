import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../data/request_repository.dart';
import '../data/invite_mailer.dart';
import '../data/services.dart';
import '../domain/staff_access.dart';
import '../widgets/app_header.dart';

/// スタッフ管理（責任者のみ）。メールで招待し（登録フォームのリンクを送る）、登録済みの権限を変更する。
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
          const AppHeader(title: 'スタッフ管理', background: AppColors.bg),
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
                              _InviteForm(me: me),
                              const _PendingInvites(),
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
              Text(u.phone.isEmpty ? u.email : '${u.email}　${u.phone}',
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

/// 招待：メールアドレスと権限を決めて、登録フォームのリンクをメールで送る。
class _InviteForm extends StatefulWidget {
  const _InviteForm({required this.me});
  final String me;

  @override
  State<_InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends State<_InviteForm> {
  final _email = TextEditingController();
  bool _canRequest = false;
  bool _canEdit = true;
  bool _manager = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    if (!email.contains('@')) {
      messenger.showSnackBar(const SnackBar(content: Text('メールアドレスを入力してください')));
      return;
    }
    setState(() => _busy = true);
    try {
      await Services.repo.saveInvite(email,
          canRequest: _canRequest,
          canEdit: _canEdit,
          manager: _manager,
          invitedBy: widget.me);
      await const InviteMailer().send(email);
      _email.clear();
      messenger.showSnackBar(SnackBar(content: Text('$email へ招待メールを送りました')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('送れませんでした：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      margin: EdgeInsets.only(bottom: r.y(10)),
      padding: EdgeInsets.all(r.x(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.ink),
        borderRadius: BorderRadius.circular(r.x(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('スタッフを招待', style: AppText.noto(r.x(16))),
          SizedBox(height: r.y(8)),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
                labelText: 'メールアドレス', border: OutlineInputBorder()),
          ),
          SizedBox(height: r.y(8)),
          Wrap(spacing: 8, children: [
            for (final o in const [
              ('編集者', false, true),
              ('依頼者', true, false),
              ('両方', true, true),
            ])
              ChoiceChip(
                label: Text(o.$1),
                selected: _canRequest == o.$2 && _canEdit == o.$3,
                onSelected: (_) => setState(() {
                  _canRequest = o.$2;
                  _canEdit = o.$3;
                }),
              ),
          ]),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('責任者にする'),
            value: _manager,
            onChanged: (v) => setState(() => _manager = v),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _send,
              style: FilledButton.styleFrom(backgroundColor: AppColors.blue),
              child: Text(_busy ? '送信中…' : '招待メールを送る'),
            ),
          ),
          SizedBox(height: r.y(4)),
          Text('メールのリンクから名前とパスワードを登録すると、この権限が付きます。',
              style: AppText.noto(r.x(12), color: AppColors.stepGrey)),
        ],
      ),
    );
  }
}

/// 送信済みで、まだ登録されていない招待。再送・取り消しができる。
class _PendingInvites extends StatelessWidget {
  const _PendingInvites();

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return StreamBuilder<List<Invite>>(
      stream: Services.repo.watchInvites(),
      builder: (context, snap) {
        final list = snap.data ?? const <Invite>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: EdgeInsets.only(bottom: r.y(10)),
          padding: EdgeInsets.all(r.x(14)),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.amber, width: 3),
            borderRadius: BorderRadius.circular(r.x(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('登録待ちの招待', style: AppText.noto(r.x(16))),
              for (final i in list)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(i.email),
                  subtitle: Text(
                      '${i.access.label}${i.access.manager ? '　責任者' : ''}'),
                  trailing: Wrap(children: [
                    TextButton(
                      onPressed: () async {
                        final m = ScaffoldMessenger.of(context);
                        try {
                          await const InviteMailer().send(i.email);
                          m.showSnackBar(
                              const SnackBar(content: Text('再送しました')));
                        } catch (e) {
                          m.showSnackBar(
                              SnackBar(content: Text('送れませんでした：$e')));
                        }
                      },
                      child: const Text('再送'),
                    ),
                    TextButton(
                      onPressed: () => Services.repo.cancelInvite(i.email),
                      child: const Text('取消'),
                    ),
                  ]),
                ),
            ],
          ),
        );
      },
    );
  }
}
