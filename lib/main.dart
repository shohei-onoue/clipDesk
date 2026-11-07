import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/brief_confirm_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/delivery_library_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/request_detail_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/request_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 保存済みの認証情報ではホームへ進まず、毎回ボタン操作で認証する。
  runApp(const ClipDeskApp());
}

class ClipDeskApp extends StatelessWidget {
  const ClipDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clip Desk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      initialRoute: '/',
      routes: {
        '/': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/drawer': (_) => const RequestListScreen(),
        '/chat': (_) => const ChatScreen(),
        '/brief': (_) => const BriefConfirmScreen(),
        '/notifications': (_) => const NotificationsScreen(),
        '/library': (_) => const DeliveryLibraryScreen(),
      },
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
