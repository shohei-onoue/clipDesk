import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';

/// スタッフの新規登録。登録しただけでは何も見られず、責任者の承認（権限の割り当て）後に使える。
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _message(String code) => switch (code) {
        'email-already-in-use' => 'このメールアドレスはすでに登録されています',
        'invalid-email' => 'メールアドレスの形式が正しくありません',
        'weak-password' => 'パスワードは6文字以上にしてください',
        'operation-not-allowed' => '新規登録は現在受け付けていません',
        'network-request-failed' => '通信に失敗しました。接続を確認してください',
        _ => '登録できませんでした（$code）',
      };

  Future<void> _submit() async {
    if (_busy) return;
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty || email.isEmpty || _password.text.isEmpty) {
      setState(() => _error = '名前・メールアドレス・パスワードを入力してください');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email, password: _password.text);
      final user = cred.user!;
      await user.updateDisplayName(name);
      // 承認画面に表示するための記録（権限は付かない）。失敗しても登録自体は完了。
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': email,
          'name': name,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('users/${user.uid} の保存に失敗しました: $e');
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text('スタッフ新規登録', style: AppText.noto(18)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('登録後、責任者が承認すると使えるようになります。',
                    style: AppText.noto(14, height: 1.6)),
                const SizedBox(height: 16),
                TextField(controller: _name, decoration: deco('名前')),
                const SizedBox(height: 12),
                TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: deco('メールアドレス')),
                const SizedBox(height: 12),
                TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: deco('パスワード（6文字以上）')),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: AppText.noto(14, color: AppColors.danger)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    style:
                        FilledButton.styleFrom(backgroundColor: AppColors.blue),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('登録する',
                            style: AppText.noto(16, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
