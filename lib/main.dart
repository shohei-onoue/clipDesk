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
      // 画面が縦長の端末より横に広い場合（PC・タブレット）は、
      // デザイン比率 390:844 の枠を中央に置き、比率レイアウトが崩れないようにする。
      builder: (context, child) {
        final size = MediaQuery.sizeOf(context);
        const aspect = 390 / 844;
        if (size.width / size.height <= aspect + 0.05) return child!;
        final w = size.height * aspect;
        return ColoredBox(
          color: const Color(0xFF111111),
          child: Center(
            child: SizedBox(
              width: w,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(size: Size(w, size.height)),
                child: ClipRect(child: child),
              ),
            ),
          ),
        );
      },
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
