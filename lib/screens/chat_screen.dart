import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/chat_widgets.dart';

/// 03 チャット（質問に回答中）
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: '指示'),
            Expanded(
              child: BottomAlignedScroll(
                children: [
                  const AssistantMessage(
                    text: 'こんにちは。いくつか質問に答えるだけで、編集者への指示書ができます。',
                    fixedWidth: true,
                  ),
                  const AssistantMessage(text: 'どんな動画ですか？'),
                  const MyMessage('会社紹介'),
                  const AssistantMessage(text: 'どこに投稿しますか？'),
                  Padding(
                    padding: EdgeInsets.only(bottom: r.y(10)),
                    child: Wrap(
                      spacing: r.x(8),
                      runSpacing: r.y(8),
                      children: const [
                        AppChip('Instagram リール'),
                        AppChip('TikTok'),
                        AppChip('YouTube'),
                        AppChip('社内・研修'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(r.x(5)),
              child: Container(
                height: r.y(66),
                padding: EdgeInsets.symmetric(horizontal: r.x(14)),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(r.x(20)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: r.y(48),
                        padding: EdgeInsets.symmetric(horizontal: r.x(14)),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.ink),
                          borderRadius: BorderRadius.circular(r.x(16)),
                        ),
                        child: Text(
                          'ここに入力…',
                          style: AppText.noto(r.x(16),
                              weight: FontWeight.w500,
                              color: const Color(0x991A1D20),
                              height: 20.8 / 16),
                        ),
                      ),
                    ),
                    SizedBox(width: r.x(8)),
                    InkResponse(
                      onTap: () => Navigator.of(context).pushNamed('/brief'),
                      child: SizedBox(
                        width: r.x(48),
                        height: r.x(48),
                        child: Icon(Icons.send,
                            size: r.x(24), color: AppColors.bg),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
