import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/chat_widgets.dart';

/// 04 チャット（質問が終わった状態）= 指示書確認
class BriefConfirmScreen extends StatelessWidget {
  const BriefConfirmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: '指示書確認'),
            const Expanded(
              child: ColoredBox(
                color: Colors.white,
                child: BottomAlignedScroll(
                  children: [
                    AssistantMessage(text: '場面を追加しますか？'),
                    MyMessage('これで完了'),
                    AssistantMessage(
                      fixedWidth: true,
                      lines: [
                        '依頼内容のまとめ',
                        '依頼名：新商品紹介動画',
                        '動画：会社紹介　投稿先：Instagram リール',
                        '視聴者：20〜30代女性',
                        '伝えたいこと：たった3分で終わる朝のケア',
                        '主役の文字：商品名　長さ：30秒',
                        '希望納期：2026/11/14',
                        '場面：1 つ',
                      ],
                    ),
                    AssistantMessage(
                      showHeader: false,
                      fixedWidth: true,
                      text: 'これで指示書ができました。下の「指示内容を確認する」を押して、内容を確かめてから依頼してください。',
                    ),
                  ],
                ),
              ),
            ),
            Container(
              color: Colors.white,
              padding: EdgeInsets.all(r.x(5)),
              child: Material(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(r.x(20)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(r.x(20)),
                  onTap: () {},
                  child: SizedBox(
                    height: r.y(66),
                    width: double.infinity,
                    child: Center(
                      child: Text('指示内容を確認する',
                          style: AppText.noto(r.x(16),
                              color: Colors.white, height: 20.8 / 16)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
