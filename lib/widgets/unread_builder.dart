import 'package:flutter/material.dart';

import '../data/services.dart';
import '../domain/home_logic.dart';
import '../domain/request_status.dart';
import '../domain/video_request.dart';

/// 通知の一覧（削除していないもの）と、そのうちの未読を渡す。
/// 既読・削除は通知ごとの状態（[NotificationState]）で決める。
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
    return StreamBuilder<NotificationState>(
      stream: Services.repo.watchNotificationState(uid),
      builder: (context, state) => StreamBuilder<List<AppNotification>>(
        stream: Services.repo.watchNotifications(uid, role),
        builder: (context, snap) {
          final st = state.data ?? const NotificationState();
          final all = st.visible(snap.data ?? const <AppNotification>[]);
          return builder(context, all, st.unread(all));
        },
      ),
    );
  }
}
