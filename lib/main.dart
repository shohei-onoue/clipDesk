import 'package:flutter/material.dart';

import 'screens/brief_confirm_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/request_list_screen.dart';

void main() => runApp(const ClipDeskApp());

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
      },
    );
  }
}
