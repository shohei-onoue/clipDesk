import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsBinding;
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_settings.dart';
import 'core/debug_auto_login.dart';
import 'firebase_options.dart';
import 'screens/brief_confirm_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/delivery_library_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/request_detail_screen.dart';
import 'screens/home_screen.dart';
import 'screens/staff_invite_screen.dart';
import 'screens/requester_home_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/register_screen.dart';
import 'screens/staff_admin_screen.dart';
import 'screens/login_screen.dart';
import 'screens/request_list_screen.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 保存済みの認証情報ではホームへ進まず、毎回ボタン操作で認証する。
  // ただしデバッグ実行（ポート 5001／5002）だけは、テスト用アカウントで自動ログインする。
  await AppSettings.instance.load();
  final auto = await debugAutoLogin();
  // Web でも、VoiceOver・TalkBack・ブラウザの読み上げ機能が画面の文字を読めるよう、
  // アクセシビリティ情報（セマンティクス）を最初からオンにする。
  SemanticsBinding.instance.ensureSemantics();
  runApp(ClipDeskApp(autoLoggedIn: auto));
}

class ClipDeskApp extends StatefulWidget {
  const ClipDeskApp({super.key, this.autoLoggedIn = false});

  /// デバッグの自動ログインが済んでいるか（済んでいればメイン画面から始める）。
  final bool autoLoggedIn;

  @override
  State<ClipDeskApp> createState() => _ClipDeskAppState();
}

class _ClipDeskAppState extends State<ClipDeskApp> {
  bool get autoLoggedIn => widget.autoLoggedIn;

  @override
  void initState() {
    super.initState();
    AppSettings.instance.addListener(_onSettings);
    // ログインしたユーザーが保存した設定を反映する（ユーザーごとの設定）。
    _authSub = FirebaseAuth.instance
        .authStateChanges()
        .listen((u) => AppSettings.instance.bindUser(u?.uid));
  }

  StreamSubscription<User?>? _authSub;

  @override
  void dispose() {
    AppSettings.instance.removeListener(_onSettings);
    _authSub?.cancel();
    super.dispose();
  }

  /// 設定（文字の大きさ・色の組み合わせ・ふりがな）が変わったら、画面全体を作り直す。
  /// 色は const ではなく、const のウィジェットや State に残った値もあるため、全部を再構築する。
  void _onSettings() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void mark(Element e) {
        e.markNeedsBuild();
        e.visitChildren(mark);
      }

      WidgetsBinding.instance.rootElement?.visitChildren(mark);
    });
  }

  @override
  Widget build(BuildContext context) {
    final routes = <String, WidgetBuilder>{
      '/': (_) => const LoginScreen(),
      '/register': (_) => const RegisterScreen(),
      '/staff': (_) => const StaffAdminScreen(),
      '/staff/invite': (_) => const StaffInviteScreen(),
      '/menu': (_) => const MenuScreen(),
      '/progress': (_) => const ProgressScreen(),
      // ホームは依頼者ページのUIに差し替え中。元のホーム画面は '/home_old' に残している。
      '/home': (_) => const RequesterHomeScreen(),
      '/home_old': (_) => const HomeScreen(),
      '/requester': (_) => const RequesterHomeScreen(),
      '/drawer': (_) => const RequestListScreen(),
      '/chat': (_) => const ChatScreen(),
      '/brief': (_) => const BriefConfirmScreen(),
      '/notifications': (_) => const NotificationsScreen(),
      '/library': (_) => const DeliveryLibraryScreen(),
      '/settings': (_) => const SettingsScreen(),
    };
    return MaterialApp(
      title: 'Clip Desk',
      debugShowCheckedModeBanner: false,
      // 文字の大きさ（設定）。「小」は従来のまま（1倍）、「中」は1.5倍、「大」は2倍。
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(AppSettings.instance.textSize.scale)),
        child: child ?? const SizedBox.shrink(),
      ),
      theme: ThemeData(useMaterial3: true),
      // 日付選択（カレンダー）などの標準部品を日本語にする。
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 招待メールのリンクから開いたときは、登録フォームから始める。
      initialRoute: kIsWeb &&
              FirebaseAuth.instance.isSignInWithEmailLink(Uri.base.toString())
          ? '/register'
          : (autoLoggedIn ? '/menu' : '/'),
      routes: routes,
      // 最初の画面は1枚だけにする。標準では「/menu」から始めると、下にログイン画面（/）が
      // 積まれ、戻る操作が重なるとログイン画面（＝ログアウトしたように見える）へ戻ってしまう。
      onGenerateInitialRoutes: (name) => [
        MaterialPageRoute<void>(
          settings: RouteSettings(name: name),
          builder: routes[name] ?? routes['/']!,
        ),
      ],
      onGenerateRoute: (settings) {
        if (settings.name == '/request' && settings.arguments is String) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                RequestDetailScreen(requestId: settings.arguments as String),
          );
        }
        return null;
      },
    );
  }
}
