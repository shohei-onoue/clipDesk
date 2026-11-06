import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/filter_chips_row.dart';
import '../widgets/notice_card.dart';
import '../widgets/step_progress_card.dart';

/// 01 ホーム（進捗状況）
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: '進捗状況'),
            Expanded(
              child: Container(
                color: Colors.white,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                      r.x(10), r.y(8), r.x(10), r.y(12)),
                  children: [
                    FilterChipsRow(
                      selected: _filter,
                      onChanged: (i) => setState(() => _filter = i),
                    ),
                    SizedBox(height: r.y(10)),
                    NoticeCard(
                      text: '編集済みの動画が届いています（チェック依頼 1 件）',
                      onTap: () => Navigator.of(context).pushNamed('/drawer'),
                    ),
                    SizedBox(height: r.y(21)),
                    const StepProgressCard(title: '店舗紹介 / 秋のシーズンムービー'),
                    SizedBox(height: r.y(10)),
                    const StepProgressCard(title: '店舗紹介 / 秋のシーズンムービー'),
                  ],
                ),
              ),
            ),
            _BottomActionBar(
              onNew: () => Navigator.of(context).pushNamed('/chat'),
              onCheck: () => Navigator.of(context).pushNamed('/drawer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({this.onNew, this.onCheck});

  final VoidCallback? onNew;
  final VoidCallback? onCheck;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    Widget divider() => Container(
          width: 1,
          height: r.y(40),
          color: Colors.white54,
        );
    return Container(
      height: r.y(75),
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(r.x(20)),
      ),
      child: Row(
        children: [
          Expanded(
              child: _Action(
                  icon: Icons.note_add, label: '新規依頼', onTap: onNew)),
          divider(),
          Expanded(
              child: _Action(
                  icon: Icons.assignment_outlined,
                  label: '依頼確認',
                  onTap: onCheck)),
          divider(),
          const Expanded(
              child: _Action(icon: Icons.settings_outlined, label: '設定')),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return InkWell(
      onTap: onTap,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: r.x(32), color: Colors.white),
              Text(label,
                  style: AppText.noto(r.x(20),
                      color: Colors.white, height: 32 / 20)),
            ],
          ),
        ),
      ),
    );
  }
}
