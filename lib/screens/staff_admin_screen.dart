import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/night_theme.dart';
import '../core/responsive.dart';
import '../data/request_repository.dart';
import '../data/invite_mailer.dart';
import '../data/services.dart';
import '../domain/staff_access.dart';
import '../widgets/app_icon.dart';
import '../widgets/role_chip.dart';
import '../widgets/app_header.dart';

/// スタッフ管理（責任者のみ）。登録済みのスタッフを一覧で表示し、権限を変更できる。
/// 右下の「＋」から招待画面（/staff/invite）へ進む。
/// 権限：編集者／依頼者／両方。責任者の印は別に付けられる。承認の取り消しもできる。
/// 自分自身の権限は変更できない（ルールでも拒否される）。
class StaffAdminScreen extends StatelessWidget {
  const StaffAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final me = Services.uid;
    return Theme(
      data: nightTheme,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: FloatingActionButton(
          tooltip: 'スタッフを招待',
          backgroundColor: AppColors.blue,
          foregroundColor: AppColors.white,
          onPressed: () => Navigator.of(context).pushNamed('/staff/invite'),
          child: const AppIcon(AppIcons.addCircle,
              size: 32, color: AppColors.white),
        ),
        body: SafeArea(
          child: Column(children: [
            const AppHeader(title: 'スタッフ管理'),
            Expanded(
              child: me == null
                  ? Center(
                      child: Text('ログインしてください',
                          style: AppText.dark(14, weight: FontWeight.w400)))
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
                            final list = [...?users.data]..sort((a, b) {
                                // ログイン者を先頭に、あとはメールアドレス順。
                                if (a.uid == me) return -1;
                                if (b.uid == me) return 1;
                                return a.email.compareTo(b.email);
                              });
                            return ListView(
                              padding: EdgeInsets.fromLTRB(
                                  r.x(10), r.x(10), r.x(10), r.x(88)),
                              children: [
                                const _PendingInvites(),
                                for (final u in list)
                                  _UserTile(user: u, isMe: u.uid == me),
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
      ),
    );
  }
}

class _UserTile extends StatefulWidget {
  const _UserTile({required this.user, required this.isMe});
  final StaffUser user;

  /// ログイン者本人のカード。ログイン者バッヂを付け、編集・削除はできない（自分の権限は変えられない）。
  final bool isMe;

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  Future<void> _edit(StaffAccess a) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _EditDialog(user: widget.user, access: a, isMe: widget.isMe),
    );
    if (saved == true) {
      messenger.showSnackBar(const SnackBar(content: Text('スタッフ情報を更新しました')));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(
            side: BorderSide(color: AppColors.white.withValues(alpha: 0.16)),
            borderRadius: BorderRadius.circular(15)),
        title: Text('スタッフ情報を削除します', style: AppText.dark(16)),
        content: Text(
            widget.isMe
                ? 'あなた自身の登録情報と権限を削除します。削除するとログアウトされ、ほかの管理者がいないと管理画面を使えなくなります。'
                : '${widget.user.name.isEmpty ? widget.user.email : widget.user.name} の登録情報と権限を削除します。',
            style: AppText.dark(14, weight: FontWeight.w400)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.ink),
              child: const Text('削除する')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await Services.repo
          .deleteStaff(widget.user.uid, email: widget.user.email);
      if (widget.isMe) {
        // 自分の情報を消したので、ログアウトして最初の画面へ戻る。
        await FirebaseAuth.instance.signOut();
        nav.pushNamedAndRemoveUntil('/', (_) => false);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('削除できませんでした：$e')));
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
        // 権限を読み込む前は「承認待ち」にしない（amber の枠が一瞬出るのを防ぐ）。
        final waiting = !snap.hasData;
        final card = Container(
          margin: EdgeInsets.only(bottom: r.y(10)),
          padding: EdgeInsets.fromLTRB(r.x(14), r.x(6), r.x(4), r.x(14)),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.08),
            border: Border.all(
                color: a.approved || waiting
                    ? AppColors.white.withValues(alpha: 0.16)
                    : AppColors.amber,
                width: a.approved || waiting ? 1 : 2),
            borderRadius: BorderRadius.circular(r.x(15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: r.x(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.name.isEmpty ? '（名前なし）' : u.name,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.dark(r.x(16))),
                          Text(u.email,
                              style: AppText.dark(r.x(13),
                                  color:
                                      AppColors.white.withValues(alpha: 0.7))),
                          if (!a.approved && !waiting)
                            Text('承認待ち',
                                style: AppText.dark(r.x(13),
                                    color: AppColors.amber)),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'メニュー',
                    icon: const Icon(Icons.more_vert, color: AppColors.white),
                    color: AppColors.ink,
                    shape: RoundedRectangleBorder(
                        side: BorderSide(
                            color: AppColors.white.withValues(alpha: 0.16)),
                        borderRadius: BorderRadius.circular(r.x(10))),
                    onSelected: (v) {
                      if (v == 'edit') _edit(a);
                      if (v == 'delete') _delete();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                          value: 'edit',
                          child: Text('編集',
                              style:
                                  AppText.dark(14, weight: FontWeight.w400))),
                      PopupMenuItem(
                          value: 'delete',
                          child: Text('削除',
                              style:
                                  AppText.dark(14, weight: FontWeight.w400))),
                    ],
                  ),
                ],
              ),
              SizedBox(height: r.y(6)),
              Padding(
                padding: EdgeInsets.only(right: r.x(10)),
                child: Row(children: [
                  RoleChip('編集者', selected: a.canEdit),
                  SizedBox(width: r.x(8)),
                  RoleChip('依頼者', selected: a.canRequest),
                  const Spacer(),
                  RoleChip('管理者権限', selected: a.manager),
                ]),
              ),
            ],
          ),
        );
        if (!widget.isMe) return card;
        // ログイン者バッヂ：カードの外、左上角の真上に付ける。
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.x(12), vertical: r.x(3)),
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(r.x(8)),
              ),
              child: Text('ログイン',
                  style: AppText.dark(r.x(12), color: AppColors.ink)),
            ),
            card,
          ],
        );
      },
    );
  }
}

/// 送信済みで、まだ登録されていない招待（登録待ちスタッフ）。再送・取消ができる。
class _PendingInvites extends StatelessWidget {
  const _PendingInvites();

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return StreamBuilder<List<Invite>>(
      stream: Services.repo.watchInvites(),
      builder: (context, snap) {
        final list = snap.data ?? const <Invite>[];
        // 招待1件ごとに1枚のカード（スタッフカードと同じ作り）。
        return Column(children: [
          for (final i in list)
            Container(
              margin: EdgeInsets.only(bottom: r.y(10)),
              padding: EdgeInsets.all(r.x(14)),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.08),
                border: Border.all(color: AppColors.amber, width: 2),
                borderRadius: BorderRadius.circular(r.x(15)),
              ),
              child: Row(
                // ボタンはカードの高さに対して上下中央。
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('登録待ちスタッフ', style: AppText.dark(r.x(16))),
                        Text(i.email,
                            style: AppText.dark(r.x(13),
                                color: AppColors.white.withValues(alpha: 0.7))),
                      ],
                    ),
                  ),
                  _InviteButton(
                    icon: AppIcons.send,
                    label: '再送',
                    onTap: () async {
                      final m = ScaffoldMessenger.of(context);
                      try {
                        await const InviteMailer().send(i.email);
                        m.showSnackBar(const SnackBar(content: Text('再送しました')));
                      } catch (e) {
                        m.showSnackBar(SnackBar(content: Text('送れませんでした：$e')));
                      }
                    },
                  ),
                  SizedBox(width: r.x(8)),
                  _InviteButton(
                    icon: AppIcons.delete,
                    label: '取消',
                    onTap: () => Services.repo.cancelInvite(i.email),
                  ),
                ],
              ),
            ),
        ]);
      },
    );
  }
}

/// アイコンの下に語句を置いたボタン（amber 塗り、アイコンと文字は White）。
class _InviteButton extends StatelessWidget {
  const _InviteButton(
      {required this.icon, required this.label, required this.onTap});
  final AppIcons icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.amber,
        borderRadius: BorderRadius.circular(r.x(10)),
        child: InkWell(
          borderRadius: BorderRadius.circular(r.x(10)),
          onTap: onTap,
          child: ExcludeSemantics(
            child: SizedBox(
              width: r.x(56),
              height: r.x(56),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon(icon, size: r.x(24), color: AppColors.white),
                  Text(label,
                      style: AppText.dark(r.x(12), color: AppColors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// スタッフ情報の編集ダイアログ：名前、メールアドレス、区分（編集者・依頼者）、管理者権限。
/// 暗い面・White文字（デザインシステムのダイアログ）。キャンセルと「保存する」を明確に分ける。
class _EditDialog extends StatefulWidget {
  const _EditDialog(
      {required this.user, required this.access, required this.isMe});
  final StaffUser user;

  /// ログイン者本人。権限は自分では変えられない（ルールでも拒否）ので、名前とメールアドレスだけ直せる。
  final bool isMe;
  final StaffAccess access;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final _name = TextEditingController(text: widget.user.name);
  late final _email = TextEditingController(text: widget.user.email);
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  late bool _canRequest = widget.access.canRequest;
  late bool _canEdit = widget.access.canEdit;
  late bool _manager = widget.access.manager;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'エラー：メールアドレスの形式が正しくありません。入力し直してください');
      return;
    }
    if (!_canRequest && !_canEdit) {
      setState(() => _error = 'エラー：区分が選ばれていません。編集者か依頼者を1つ以上選んでください');
      return;
    }
    final newPassword = _newPassword.text;
    if (widget.isMe && newPassword.isNotEmpty) {
      if (newPassword.length < 6) {
        setState(() => _error = 'エラー：新しいパスワードが短すぎます。6文字以上で入力してください');
        return;
      }
      if (_currentPassword.text.isEmpty) {
        setState(() => _error = 'エラー：現在のパスワードが未入力です。入力してください');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.isMe && newPassword.isNotEmpty) {
        // パスワードの変更は、現在のパスワードで本人確認（再認証）してから行う。
        final user = FirebaseAuth.instance.currentUser;
        if (user == null || user.email == null) {
          throw FirebaseAuthException(code: 'no-current-user');
        }
        await user.reauthenticateWithCredential(EmailAuthProvider.credential(
            email: user.email!, password: _currentPassword.text));
        await user.updatePassword(newPassword);
      }
      await Services.repo.updateStaffProfile(widget.user.uid,
          name: _name.text.trim(), email: email);
      if (!widget.isMe) {
        await Services.repo.setStaffAccess(widget.user.uid,
            canRequest: _canRequest, canEdit: _canEdit, manager: _manager);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = switch (e.code) {
            'wrong-password' ||
            'invalid-credential' =>
              'エラー：現在のパスワードが違います。入力し直してください',
            'weak-password' => 'エラー：新しいパスワードが弱すぎます。6文字以上の別の文字列にしてください',
            'too-many-requests' => 'エラー：試行が多すぎます。しばらく待ってから、もう一度お試しください',
            'requires-recent-login' => 'エラー：本人確認が切れています。ログインし直してから、もう一度お試しください',
            _ => 'エラー：パスワードを変更できませんでした（${e.code}）。通信を確認して、もう一度お試しください',
          };
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'エラー：保存できませんでした（$e）。通信を確認して、もう一度お試しください';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Theme(
      data: nightTheme,
      child: AlertDialog(
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(
            side: BorderSide(color: AppColors.white.withValues(alpha: 0.16)),
            borderRadius: BorderRadius.circular(r.x(15))),
        title: Text('スタッフ情報を編集', style: AppText.dark(16)),
        content: SizedBox(
          width: r.x(340),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                      labelText: '名前', border: OutlineInputBorder()),
                ),
                SizedBox(height: r.y(12)),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'メールアドレス', border: OutlineInputBorder()),
                ),
                SizedBox(height: r.y(16)),
                Text(widget.isMe ? '権限選択（自分の権限は変えられません）' : '権限選択',
                    style: AppText.dark(14)),
                SizedBox(height: r.y(8)),
                Row(children: [
                  RoleChip('編集者',
                      selected: _canEdit,
                      onChanged: widget.isMe
                          ? null
                          : (v) => setState(() => _canEdit = v)),
                  SizedBox(width: r.x(8)),
                  RoleChip('依頼者',
                      selected: _canRequest,
                      onChanged: widget.isMe
                          ? null
                          : (v) => setState(() => _canRequest = v)),
                  const Spacer(),
                  RoleChip('管理者権限',
                      selected: _manager,
                      onChanged: widget.isMe
                          ? null
                          : (v) => setState(() => _manager = v)),
                ]),
                if (widget.isMe) ...[
                  SizedBox(height: r.y(16)),
                  Text('パスワードの変更（変えない場合は空欄）', style: AppText.dark(14)),
                  SizedBox(height: r.y(8)),
                  TextField(
                    controller: _currentPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: '現在のパスワード', border: OutlineInputBorder()),
                  ),
                  SizedBox(height: r.y(12)),
                  TextField(
                    controller: _newPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: '新しいパスワード（6文字以上）',
                        border: OutlineInputBorder()),
                  ),
                ],
                if (_error != null) ...[
                  SizedBox(height: r.y(12)),
                  Text(_error!,
                      style: AppText.dark(13,
                          weight: FontWeight.w400, color: AppColors.amber)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: AppColors.white),
              child: Text(_busy ? '保存中…' : '保存する')),
        ],
      ),
    );
  }
}
