import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/filter_chips_row.dart';
import '../widgets/notice_card.dart';
import '../widgets/request_card.dart';

/// 02 ドロワー（AppDrawer）: 依頼一覧の上にドロワーを開いた状態。
class RequestListScreen extends StatefulWidget {
  const RequestListScreen({super.key, this.openDrawer = true});

  /// true の間は、表示と同時にドロワーを開く。
  final bool openDrawer;

  @override
  State<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends State<RequestListScreen> {
  final _key = GlobalKey<ScaffoldState>();
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    if (widget.openDrawer) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _key.currentState?.openDrawer());
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      key: _key,
      backgroundColor: AppColors.bg,
      drawer: const AppDrawer(),
      drawerScrimColor: const Color(0x8A000000),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(
              title: 'Clip Desk',
              titleSize: 32,
              background: AppColors.bg,
            ),
            Expanded(
              child: ListView(
                padding:
                    EdgeInsets.fromLTRB(r.x(10), r.y(8), r.x(10), r.y(12)),
                children: [
                  FilterChipsRow(
                    selected: _filter,
                    idleColor: AppColors.bg,
                    selectedTextColor: AppColors.bg,
                    onChanged: (i) => setState(() => _filter = i),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: r.y(10)),
                    child: const NoticeCard(
                      text: '編集済みの動画が届いています（チェック依頼 1 件）',
                      background: AppColors.amber,
                      borderColor: AppColors.ink,
                      bellColor: AppColors.ink,
                    ),
                  ),
                  for (final d in _data)
                    Padding(
                      padding: EdgeInsets.only(bottom: r.y(10)),
                      child: RequestCard(
                        progress: d.progress,
                        progressLabel: d.label,
                        title: d.title,
                        meta: d.meta,
                        tag: d.tag,
                        tagColor: d.tag == '確認中'
                            ? AppColors.amber
                            : AppColors.blue,
                        tagTextColor: d.tag == '確認中'
                            ? AppColors.ink
                            : AppColors.bg,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(r.x(5)),
              child: Material(
                color: AppColors.blue,
                borderRadius: BorderRadius.circular(r.x(20)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(r.x(20)),
                  onTap: () => Navigator.of(context).pushNamed('/chat'),
                  child: SizedBox(
                    height: r.y(66),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.note_add,
                            size: r.x(24), color: AppColors.bg),
                        SizedBox(width: r.x(14)),
                        Text('新規依頼',
                            style: AppText.noto(r.x(16),
                                color: AppColors.bg,
                                height: 20.8 / 16,
                                letterSpacing: 0.32)),
                      ],
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

class _Req {
  const _Req(this.progress, this.label, this.title, this.meta, this.tag);

  final double progress;
  final String label;
  final String title;
  final String meta;
  final String tag;
}

const _data = [
  _Req(0.25, '25%', '新商品紹介動画', '担当 佐藤　納期 2026/10/30', '編集中'),
  _Req(0.75, '75%', '店舗紹介 / 秋のシーズンムービー', '担当 田中　納期 2026/11/02', '確認中'),
  _Req(0.50, '50%', 'スタッフインタビュー vol.01', '担当 山本　納期 2026/10/28', '編集中'),
  _Req(0.25, '25%', '採用PR 15秒', '担当 未定　納期 2026/11/08', '編集中'),
  _Req(0.50, '50%', '研修動画 vol.2', '担当 山本　納期 2026/11/04', '編集中'),
  _Req(1.00, '完了', '夏のキャンペーン', '担当 田中　納期 2026/09/20', '公開済'),
];
