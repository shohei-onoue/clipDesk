import 'package:flutter/material.dart';

import '../data/services.dart';
import '../domain/home_logic.dart';
import '../domain/request_status.dart';
import '../domain/video_request.dart';

/// 通知の一覧と、そのうちの未読を渡す。
class UnreadBuilder extends StatelessWidget {
  const UnreadBuilder({
    super.key,
    required this.uid,
    required this.role,
    required this.builder,
  });

  final String uid;
  final UserRole role;
  final Widget Function(BuildContext context, List<AppNotification> all,
      List<AppNotification> unread) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime?>(
      stream: Services.repo.watchNotificationsSeenAt(uid),
      builder: (context, seen) => StreamBuilder<List<AppNotification>>(
        stream: Services.repo.watchNotifications(uid, role),
        builder: (context, snap) {
          final all = snap.data ?? const <AppNotification>[];
          // 処理が必要な通知は、見ても消さない。承認・取り消しは、見たら外す。
          final open = [
            for (final n in all)
              if (n.type != NotificationType.approved &&
                  n.type != NotificationType.cancelled)
                n
              else if (unreadOf([n], seen.data).isNotEmpty)
                n,
          ];
          return builder(context, open, open);
        },
      ),
    );
  }
}
