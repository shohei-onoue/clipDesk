import 'package:firebase_auth/firebase_auth.dart';

/// 招待メールの送信。Firebase Authentication の「メールリンク」で、登録フォームへのリンクを送る。
/// メールの文面はFirebaseコンソール（Authentication → テンプレート）で変えられる。
class InviteMailer {
  const InviteMailer();

  static const _baseUrl = 'https://clipdesk-app.web.app/';

  Future<void> send(String email) =>
      FirebaseAuth.instance.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: ActionCodeSettings(
          // リンクを開くと、このURLで登録フォームが開く。メールアドレスは入力欄に自動で入る。
          url: '$_baseUrl?email=${Uri.encodeQueryComponent(email)}',
          handleCodeInApp: true,
        ),
      );
}
