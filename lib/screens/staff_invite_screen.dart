import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/night_theme.dart';
import '../core/responsive.dart';
import '../data/invite_mailer.dart';
import '../data/services.dart';
import '../widgets/app_header.dart';
import '../widgets/tips_card.dart';

/// スタッフ招待（責任者のみ）。メールアドレスと区分を決め、登録フォームのリンクをメールで送る。
/// 「編集者」「依頼者」「管理者」はトグルスイッチで入り切りする。編集者・依頼者は1つ以上が必要。
class StaffInviteScreen extends StatefulWidget {
  const StaffInviteScreen({super.key});

  @override
  State<StaffInviteScreen> createState() => _StaffInviteScreenState();
}

class _StaffInviteScreenState extends State<StaffInviteScreen> {
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
    final me = Services.uid;
    final email = _email.text.trim();
    if (_busy || me == null) return;
    final messenger = ScaffoldMessenger.of(context);
    if (!email.contains('@')) {
      messenger.showSnackBar(const SnackBar(content: Text('メールアドレスを入力してください')));
      return;
    }
    if (!_canRequest && !_canEdit) {
      messenger.showSnackBar(const SnackBar(content: Text('区分を1つ以上選んでください')));
      return;
    }
    setState(() => _busy = true);
    try {
      await Services.repo.saveInvite(email,
          canRequest: _canRequest,
          canEdit: _canEdit,
          manager: _manager,
          invitedBy: me);
      await const InviteMailer().send(email);
      messenger.showSnackBar(SnackBar(content: Text('$email へ招待メールを送りました')));
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('送れませんでした：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Theme(
      data: nightTheme,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          child: Column(children: [
            const AppHeader(title: 'スタッフ招待'),
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(r.x(14)),
                children: [
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'メールアドレス', border: OutlineInputBorder()),
                  ),
                  SizedBox(height: r.y(16)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('編集者'),
                    value: _canEdit,
                    onChanged: (v) => setState(() => _canEdit = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('依頼者'),
                    value: _canRequest,
                    onChanged: (v) => setState(() => _canRequest = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('管理者'),
                    value: _manager,
                    onChanged: (v) => setState(() => _manager = v),
                  ),
                  SizedBox(height: r.y(8)),
                  // 高さ56、幅は文字＋左右の余白20ずつ、角の丸み10。
                  Align(
                    child: FilledButton(
                      onPressed: _busy ? null : _send,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        minimumSize: const Size(0, 56),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: AppColors.blue,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(_busy ? '送信中…' : '招待メールを送る',
                          style: AppText.dark(18)),
                    ),
                  ),
                  SizedBox(height: r.y(16)),
                  const TipsCard(
                      '招待されたスタッフがメールのリンクから登録フォームへ入力し終えると、設定した権限で登録されます。'),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
