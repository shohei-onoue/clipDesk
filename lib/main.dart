import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/brief_confirm_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/request_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 保存されたログイン情報の読み込みを待ってから、最初の画面を決める。
  final user = await FirebaseAuth.instance.authStateChanges().first;
  runApp(ClipDeskApp(loggedIn: user != null));
}

class ClipDeskApp extends StatelessWidget {
  const ClipDeskApp({super.key, this.loggedIn = false});

  /// ログイン済みなら、オープニングとログインを飛ばしてホームから始める。
  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clip Desk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      initialRoute: loggedIn ? '/home' : '/',
      routes: {
        '/': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/drawer': (_) => const RequestListScreen(),
        '/chat': (_) => const ChatScreen(),
        '/brief': (_) => const BriefConfirmScreen(),
      },
    );
  }
}
