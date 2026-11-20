import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'app_settings.dart';
import 'debug_auto_login.dart';

/// アプリ起動時の読み込み。画面（オープニング動画）を先に出し、この間に Firebase などを準備する。
/// 準備ができるまで、ログインフォームは表示しない。
class Boot {
  Boot._();

  /// 読み込みが終わったら true。
  static final ValueNotifier<bool> ready = ValueNotifier<bool>(false);

  /// デバッグの自動ログインが済んでいるか（済んでいればメイン画面へ進む）。
  static bool autoLoggedIn = false;

  /// 招待メールのリンクから開いたか（登録フォームへ進む）。
  static bool openedByInviteLink = false;

  static Future<void>? _running;

  static Future<void> run() => _running ??= _run();

  static Future<void> _run() async {
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      // ログインしたユーザーが保存した設定を反映する（ユーザーごとの設定）。
      FirebaseAuth.instance
          .authStateChanges()
          .listen((u) => AppSettings.instance.bindUser(u?.uid));
      autoLoggedIn = await debugAutoLogin();
      openedByInviteLink = kIsWeb &&
          FirebaseAuth.instance.isSignInWithEmailLink(Uri.base.toString());
    } catch (e) {
      debugPrint('起動時の読み込みに失敗しました：$e');
    }
    ready.value = true;
  }
}
