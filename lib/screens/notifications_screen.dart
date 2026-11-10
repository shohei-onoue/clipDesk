import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_header.dart';
import '../widgets/list_helpers.dart';
import '../widgets/notice_card.dart';
import '../widgets/role_builder.dart';
import '../widgets/unread_builder.dart';

/// 通知一覧。タップで該当の案件詳細を開く。
/// 既読は暫定で「この画面を開いていた時刻」までを既読とする（通知ごとの既読はFigJamで未確定）。
/// 開いている間は新着（未読）に印を付け、離れるときに既読にする。
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  void _markSeen() {
    final uid = Services.uid;
    if (uid != null) Services.repo.markNotificationsSeen(uid);
  }

  @override
  void dispose() {
    _markSeen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: AppColors.ink,
      bottomNavigationBar: const AppBottomBar(),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(children: [
          const AppHeader(title: '通知'),
          Expanded(
            child: RoleBuilder(
              dark: true,
              builder: (context, uid, role) => UnreadBuilder(
                uid: uid,
                role: role,
                builder: (context, list, unread) {
                  final unreadIds = {for (final n in unread) n.id};
                  return ListView(
                    padding: EdgeInsets.all(r.x(10)),
                    children: [
                      if (list.isEmpty) emptyTextDark(context, '通知はありません'),
                      for (final n in list)
                        Padding(
                          padding: EdgeInsets.only(bottom: r.y(8)),
                          child: NoticeCard(
                            text: unreadIds.contains(n.id)
                                ? '【新着】${n.message}'
                                : n.message,
                            // 既読は枠とベルを暗くして、新着と区別する（新着は語句【新着】も付く）。
                            borderColor: unreadIds.contains(n.id)
                                ? AppColors.amber
                                : AppColors.white.withValues(alpha: 0.16),
                            bellColor: unreadIds.contains(n.id)
                                ? AppColors.amber
                                : AppColors.white.withValues(alpha: 0.7),
                            onTap: () {
                              _markSeen();
                              openRequest(context, n.requestId);
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
