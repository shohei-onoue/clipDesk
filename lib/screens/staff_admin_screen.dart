import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import '../core/app_colors.dart';
import '../core/part_colors.dart';
import '../core/app_text.dart';
import '../core/night_theme.dart';
import '../core/responsive.dart';
import '../data/request_repository.dart';
import '../data/invite_mailer.dart';
import '../data/services.dart';
import '../domain/staff_access.dart';
import '../widgets/app_icon.dart';
import '../widgets/role_chip.dart';
import '../widgets/swipe_actions.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/hold_to_confirm.dart';
import '../widgets/ruby_text.dart';

/// スタッフ管理（責任者のみ）。登録済みのスタッフを一覧で表示する。
/// 右下の「＋」から招待画面（/staff/invite）へ進む。
/// 権限：全員が依頼も編集もできる。責任者の印は、招待するときに付ける。
/// 編集できるのはログイン者本人の情報（名前・メールアドレス・パスワード）だけ。
/// 削除（承認の取り消し）は、5秒の長押し。
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
        drawer: const AppDrawer(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: FloatingActionButton(
          tooltip: 'スタッフを招待',
          backgroundColor: PartColors.toggleFill,
          foregroundColor: AppColors.on(PartColors.toggleFill),
          onPressed: () => Navigator.of(context).pushNamed('/staff/invite'),
          child: AppIcon(AppIcons.addCircle,
              size: 32, color: AppColors.on(PartColors.toggleFill)),
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
                                  // 一覧が入れ替わっても、長押し中の削除が別の人に移らないようにする。
                                  _UserTile(
                                      key: ValueKey(u.uid),
                                      user: u,
                                      isMe: u.uid == me),
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
  const _UserTile({super.key, required this.user, required this.isMe});
  final StaffUser user;

  /// ログイン者本人のカード。「ログイン」の印を付ける。編集できるのは、このカードだけ。
  final bool isMe;

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  Future<void> _edit(StaffAccess a) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _EditDialog(user: widget.user, access: a),
    );
    if (saved == true) {
      messenger.showSnackBar(const SnackBar(content: Text('スタッフ情報を更新しました')));
    }
  }

  /// 「削除」ボタンの長押しが完了したときに実行する。
  Future<void> _delete() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final isMe = widget.isMe;
    try {
      await Services.repo
          .deleteStaff(widget.user.uid, email: widget.user.email);
      if (isMe) {
        // 自分の情報を消したので、ログアウトして最初の画面へ戻る。
        await FirebaseAuth.instance.signOut();
        nav.pushNamedAndRemoveUntil('/', (_) => false);
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('スタッフ情報を削除しました')));
      }
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('エラー：削除できませんでした（$e）。通信を確認して、もう一度お試しください')));
    }
  }

  /// 削除ボタンを押している間と、短く押したときの案内。
  SwipeHold get _deleteHold {
    final u = widget.user;
    final seconds = HoldToConfirm.defaultDuration.inSeconds;
    final name = u.name.isEmpty ? u.email : u.name;
    return SwipeHold(
      popupMessage: widget.isMe
          ? 'このまま押し続けると\nあなたの情報を削除して\nログアウトします'
          : 'このまま押し続けると\n$name の情報を削除します',
      shortPressMessage: '$seconds秒間、長押しするとスタッフ情報を削除します',
    );
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
          padding: EdgeInsets.fromLTRB(r.x(14), r.x(12), r.x(14), r.x(12)),
          decoration: BoxDecoration(
            color: AppColors.gray,
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
                // 名前・メールアドレスの2行と、管理者権限のバッジは、同じ高さの中央にそろえる。
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 文字が大きいとき（中・大）は、名前と「ログイン」を折り返して並べる。
                          () {
                            final name = Text(
                                u.name.isEmpty ? '（名前なし）' : u.name,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.dark(r.x(16)));
                            final me = Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: r.x(10), vertical: r.x(2)),
                              decoration: BoxDecoration(
                                color: AppColors.amber,
                                borderRadius: BorderRadius.circular(r.x(8)),
                              ),
                              child: Text('ログイン',
                                  style: AppText.dark(r.x(12),
                                      color: PartColors.onAmber)),
                            );
                            if (r.large) {
                              return Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: r.x(8),
                                runSpacing: r.x(2),
                                children: [name, if (widget.isMe) me],
                              );
                            }
                            return Row(
                              children: [
                                Flexible(child: name),
                                if (widget.isMe) ...[
                                  SizedBox(width: r.x(8)),
                                  me,
                                ],
                              ],
                            );
                          }(),
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
                  if (a.manager && !r.large) RoleChip('管理者権限', selected: true),
                ],
              ),
              // 文字が大きいとき（中・大）は、横に並べると狭いので、下の段に置く。
              if (a.manager && r.large)
                Padding(
                  padding: EdgeInsets.only(top: r.x(8)),
                  child: RoleChip('管理者権限', selected: true),
                ),
            ],
          ),
        );
        // 左にスワイプすると、ボタンが現れる（編集は本人のカードだけ。削除は長押し）。
        final swipe = SwipeActions(
          actions: [
            if (widget.isMe)
              SwipeAction(
                  icon: Icons.edit_outlined,
                  label: '編集',
                  color: AppColors.blue,
                  onTap: () => _edit(a)),
            SwipeAction(
                icon: Icons.delete_outline,
                label: '削除',
                color: AppColors.badgeRed,
                hold: _deleteHold,
                onTap: _delete),
          ],
          child: card,
        );
        return Padding(padding: EdgeInsets.only(bottom: r.y(10)), child: swipe);
      },
    );
  }
}

/// 送信済みで、まだ登録されていない招待（登録待ちスタッフ）。再送・取消ができる。
class _PendingInvites extends StatelessWidget {
  const _PendingInvites();

  /// 招待1件のカード。文字が大きいとき（中・大）は、「再送」「取消」を下の段に置く。
  Widget _inviteCard(BuildContext context, Invite i) {
    final r = context.r;
    final texts = [
      Text('登録待ちスタッフ', style: AppText.dark(r.x(16))),
      Text(i.email,
          style: AppText.dark(r.x(13),
              color: AppColors.white.withValues(alpha: 0.7))),
    ];
    final resend = _InviteButton(
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
    );
    final cancel = _InviteButton(
      icon: AppIcons.delete,
      label: '取消',
      danger: true,
      onTap: () => Services.repo.cancelInvite(i.email),
    );
    return Container(
      margin: EdgeInsets.only(bottom: r.y(10)),
      padding: EdgeInsets.all(r.x(14)),
      decoration: BoxDecoration(
        color: AppColors.gray,
        border: Border.all(color: AppColors.amber, width: 2),
        borderRadius: BorderRadius.circular(r.x(15)),
      ),
      child: r.large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...texts,
                SizedBox(height: r.x(12)),
                Row(children: [
                  Expanded(child: resend),
                  SizedBox(width: r.x(12)),
                  Expanded(child: cancel),
                ]),
              ],
            )
          : Row(
              // ボタンはカードの高さに対して上下中央。
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: texts),
                ),
                resend,
                SizedBox(width: r.x(8)),
                cancel,
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Invite>>(
      stream: Services.repo.watchInvites(),
      builder: (context, snap) {
        final list = snap.data ?? const <Invite>[];
        // 招待1件ごとに1枚のカード（スタッフカードと同じ作り）。
        return Column(children: [
          for (final i in list) _inviteCard(context, i),
        ]);
      },
    );
  }
}

/// アイコンと語句のボタン。標準はアイコンの下に語句、文字が大きいとき（中・大）は横に並べて
/// 幅いっぱいにする。[danger]（取消）は赤。色は PartColors。
class _InviteButton extends StatelessWidget {
  const _InviteButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.danger = false});
  final bool danger;
  final AppIcons icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final fg = danger ? PartColors.onRed : PartColors.resendText;
    final image = AppIcon(icon, size: r.x(24), color: fg);
    final text = Text(label, style: AppText.dark(r.x(12), color: fg));
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: danger ? AppColors.badgeRed : PartColors.resendFill,
        borderRadius: BorderRadius.circular(r.x(10)),
        child: InkWell(
          borderRadius: BorderRadius.circular(r.x(10)),
          onTap: onTap,
          child: ExcludeSemantics(
            child: r.large
                ? ConstrainedBox(
                    constraints: BoxConstraints(minHeight: r.x(56)),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: r.x(4)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          image,
                          SizedBox(width: r.x(8)),
                          Flexible(child: text),
                        ],
                      ),
                    ),
                  )
                : SizedBox(
                    width: r.x(56),
                    height: r.x(56),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [image, text],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// ログイン者本人の情報の編集ダイアログ：名前、メールアドレス、パスワード。
/// 管理者権限は表示だけ（自分では変えられない。ルールでも拒否される）。
/// 暗い面・White文字（デザインシステムのダイアログ）。キャンセルと「保存する」を明確に分ける。
class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.user, required this.access});
  final StaffUser user;
  final StaffAccess access;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final _lastName = TextEditingController(text: widget.user.nameParts.$1);
  late final _firstName = TextEditingController(text: widget.user.nameParts.$2);
  late final _email = TextEditingController(text: widget.user.email);
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _lastName.dispose();
    _firstName.dispose();
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
    final newPassword = _newPassword.text;
    if (newPassword.isNotEmpty) {
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
      if (newPassword.isNotEmpty) {
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
          lastName: _lastName.text.trim(),
          firstName: _firstName.text.trim(),
          email: email);
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
    final lastName = TextField(
      controller: _lastName,
      decoration:
          const InputDecoration(labelText: '姓', border: OutlineInputBorder()),
    );
    final firstName = TextField(
      controller: _firstName,
      decoration:
          const InputDecoration(labelText: '名', border: OutlineInputBorder()),
    );
    final managerNote = Text('管理者はスタッフ招待権限を持ちます',
        style: AppText.dark(14,
            weight: FontWeight.w400,
            color: AppColors.white.withValues(alpha: 0.7)));
    final managerChip = RoleChip('管理者権限', selected: widget.access.manager);
    // 入力欄の間隔。文字が大きいときは、枠の上の見出しが重ならないよう広げる。
    final fieldGap = r.large ? r.tx(12) : r.y(12);
    return Theme(
      data: nightTheme,
      child: AlertDialog(
        // 文字が大きいとき（中・大）は、画面の端まで広げて入力欄の幅をとる。
        insetPadding: r.large
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
            : null,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(
            side: BorderSide(color: AppColors.white.withValues(alpha: 0.16)),
            borderRadius: BorderRadius.circular(r.x(15))),
        title: Text('スタッフ情報を編集', style: AppText.dark(16)),
        content: SizedBox(
          width: r.x(340),
          child: SingleChildScrollView(
            // 入力欄の枠の上に出る見出しが、上の端で欠けないようにする。
            padding: EdgeInsets.only(top: r.large ? r.tx(8) : 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 文字が大きいとき（中・大）は、姓と名を縦に並べる。
                if (r.large) ...[
                  lastName,
                  SizedBox(height: fieldGap),
                  firstName,
                ] else
                  Row(children: [
                    Expanded(child: lastName),
                    SizedBox(width: r.x(12)),
                    Expanded(child: firstName),
                  ]),
                SizedBox(height: fieldGap),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'メールアドレス', border: OutlineInputBorder()),
                ),
                SizedBox(height: r.y(16)),
                if (r.large) ...[
                  managerNote,
                  SizedBox(height: r.x(8)),
                  managerChip,
                ] else
                  Row(children: [
                    Expanded(child: managerNote),
                    SizedBox(width: r.x(8)),
                    managerChip,
                  ]),
                SizedBox(height: r.y(16)),
                Text('パスワードの変更（変えない場合は空欄）', style: AppText.dark(14)),
                SizedBox(height: r.y(8)),
                TextField(
                  controller: _currentPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: '現在のパスワード', border: OutlineInputBorder()),
                ),
                SizedBox(height: fieldGap),
                TextField(
                  controller: _newPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: '新しいパスワード（6文字以上）',
                      border: OutlineInputBorder()),
                ),
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
                  foregroundColor: AppColors.on(AppColors.blue)),
              child: Text(_busy ? '保存中…' : '保存する')),
        ],
      ),
    );
  }
}
