import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// デバッグ専用：ローカルで2画面を並べて確認するため、ポートごとのテスト用アカウントで
/// 自動ログインする（毎回ログインしなくてよい）。
///
/// - 動くのは「デバッグ実行（kDebugMode）」かつ Web かつ下のポートのときだけ。
///   リリースビルド（`flutter build web --release` → デプロイ）では何もしない。
/// - 5001 = 依頼者、5002 = 編集者。
const _accounts = <int, (String, String)>{
  5001: ('iraisha@example.com', 'iraisha1234'),
  5002: ('henshuusha@example.com', 'henshuusha1234'),
};

/// 自動ログインできたら true。対象外・失敗のときは false（通常のログイン画面から始まる）。
Future<bool> debugAutoLogin() async {
  if (!kDebugMode || !kIsWeb) return false;
  final account = _accounts[Uri.base.port];
  if (account == null) return false;
  final (email, password) = account;
  try {
    final auth = FirebaseAuth.instance;
    await auth.setPersistence(Persistence.LOCAL);
    if (auth.currentUser?.email?.toLowerCase() != email) {
      await auth.signInWithEmailAndPassword(email: email, password: password);
    }
    return true;
  } catch (e) {
    debugPrint('デバッグ自動ログインに失敗しました：$e');
    return false;
  }
}
