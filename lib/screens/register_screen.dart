import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/night_theme.dart';
import '../data/request_repository.dart';
import '../data/services.dart';
import '../widgets/app_header.dart';
import '../widgets/ruby_text.dart';

/// スタッフの登録フォーム。責任者からの招待メールのリンクから開く。
/// 姓・名とパスワードを決めて登録すると、招待された権限がそのまま付く。
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _lastName = TextEditingController();
  final _firstName = TextEditingController();
  final _email =
      TextEditingController(text: Uri.base.queryParameters['email'] ?? '');
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _lastName.dispose();
    _firstName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _message(String code) => switch (code) {
        'invalid-action-code' ||
        'expired-action-code' =>
          '招待のリンクが無効か、期限が切れています。責任者に再送を依頼してください',
        'invalid-email' => 'メールアドレスが、招待されたものと一致しません',
        'weak-password' => 'パスワードは6文字以上にしてください',
        'network-request-failed' => '通信に失敗しました。接続を確認してください',
        _ => '登録できませんでした（$code）',
      };

  Future<void> _submit() async {
    if (_busy) return;
    final lastName = _lastName.text.trim();
    final firstName = _firstName.text.trim();
    final name = joinName(lastName, firstName);
    final email = _email.text.trim();
    if (lastName.isEmpty ||
        firstName.isEmpty ||
        email.isEmpty ||
        _password.text.length < 6) {
      setState(() => _error = '姓・名・メールアドレスを入力し、パスワードは6文字以上にしてください');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      final cred = await auth.signInWithEmailLink(
          email: email, emailLink: Uri.base.toString());
      final user = cred.user!;
      await user.updatePassword(_password.text);
      await user.updateDisplayName(name);
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email ?? email,
          'lastName': lastName,
          'firstName': firstName,
          'name': name,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        // 招待された権限を、自分の権限にする。招待が無ければ承認待ちのまま。
        await Services.repo.claimInvite(user.uid, user.email ?? email);
      } catch (e) {
        debugPrint('登録情報の保存に失敗しました: $e');
      }
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/menu', (_) => false);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _message(e.code));
    } catch (e) {
      if (mounted) setState(() => _error = '登録できませんでした。通信を確認してください');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label) =>
        InputDecoration(labelText: label, border: const OutlineInputBorder());
    return Theme(
      data: nightTheme,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(children: [
            const AppHeader(title: 'スタッフ登録', alwaysBack: false),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                          '招待ありがとうございます。姓・名とパスワードを決めて登録してください。次回からはこのパスワードでログインします。',
                          style: AppText.dark(14,
                              weight: FontWeight.w400, height: 1.6)),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: _lastName, decoration: deco('姓'))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: TextField(
                                controller: _firstName, decoration: deco('名'))),
                      ]),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: deco('メールアドレス（招待されたもの）')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _password,
                          obscureText: true,
                          decoration: deco('パスワード（6文字以上）')),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text('エラー：$_error',
                            style: AppText.dark(14,
                                weight: FontWeight.w400,
                                color: AppColors.amber)),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _busy ? null : _submit,
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.blue,
                              foregroundColor: AppColors.onBlue),
                          child: _busy
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.onBlue))
                              : Text('登録する',
                                  style:
                                      AppText.noto(16, color: AppColors.onBlue)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
