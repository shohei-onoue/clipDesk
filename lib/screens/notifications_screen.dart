import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../domain/video_request.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_header.dart';
import '../widgets/list_helpers.dart';
import '../widgets/notice_card.dart';
import '../widgets/role_builder.dart';
import '../widgets/status_style.dart';
import '../domain/home_logic.dart';
import '../widgets/unread_builder.dart';

/// 通知一覧。タップで該当の案件詳細を開く。
/// 通知ごとに、内容の画面へ移ると既読にする。未読は枠とベルをamberで示す。
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
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
                            caption: dateText(n.createdAt),
                            text: notificationTitle(n.message),
                            // 既読は枠とベルを暗くして、新着と区別する（新着は語句【新着】も付く）。
                            borderColor: unreadIds.contains(n.id)
                                ? AppColors.amber
                                : AppColors.white.withValues(alpha: 0.16),
                            bellColor: unreadIds.contains(n.id)
                                ? AppColors.amber
                                : AppColors.white.withValues(alpha: 0.7),
                            onTap: () {
                              // 通知の内容の画面へ移ると、既読にする。
                              Services.repo.markNotificationRead(uid, n.id);
                              // 取り消された依頼は削除済みで、詳細を開けない。
                              if (n.type != NotificationType.cancelled) {
                                openRequest(context, n.requestId);
                              }
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
