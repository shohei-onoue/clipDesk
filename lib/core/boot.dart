import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'app_settings.dart';
import 'debug_auto_login.dart';

enum BootState { loading, ready, failed }

/// アプリ起動時の読み込み。画面（オープニング動画）を先に出し、この間に Firebase などを準備する。
/// 準備ができたら、動画の途中でもログインフォームを出す。失敗したらエラーと再試行を出す。
class Boot {
  Boot._();

  static final ValueNotifier<BootState> state =
      ValueNotifier<BootState>(BootState.loading);

  /// 失敗したときの理由（利用者向けではない。記録用）。
  static Object? error;

  static bool get isReady => state.value == BootState.ready;

  static bool _autoLoggedIn = false;
  static bool _openedByInviteLink = false;
  static bool _initialRouteTaken = false;
  static bool _authListening = false;
  static Future<void>? _running;

  static Future<void> run() => _running ??= _run();

  /// 失敗したあとのやり直し。
  static Future<void> retry() {
    if (state.value == BootState.loading) return _running ?? run();
    _running = null;
    state.value = BootState.loading;
    return run();
  }

  /// 起動して最初に開く画面（招待リンクなら登録、デバッグの自動ログイン済みならメイン）。
  /// 起動後に1回だけ返す。ログアウトして戻ったログイン画面では null（自動で進まない）。
  static String? takeInitialRoute() {
    if (_initialRouteTaken) return null;
    _initialRouteTaken = true;
    if (_openedByInviteLink) return '/register';
    if (_autoLoggedIn) return '/menu';
    return null;
  }

  static Future<void> _run() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
      }
      if (!_authListening) {
        _authListening = true;
        // ログインしたユーザーが保存した設定を反映する（ユーザーごとの設定）。
        FirebaseAuth.instance
            .authStateChanges()
            .listen((u) => AppSettings.instance.bindUser(u?.uid));
      }
      _autoLoggedIn = await debugAutoLogin();
      _openedByInviteLink = kIsWeb &&
          FirebaseAuth.instance.isSignInWithEmailLink(Uri.base.toString());
      error = null;
      state.value = BootState.ready;
    } catch (e) {
      debugPrint('起動時の読み込みに失敗しました：$e');
      error = e;
      state.value = BootState.failed;
    }
  }
}
