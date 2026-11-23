import 'package:flutter/material.dart';

import '../data/services.dart';
import '../domain/home_logic.dart';
import '../domain/request_status.dart';
import '../domain/video_request.dart';

/// 通知の一覧（削除していないもの）と、そのうちの未読を渡す。
/// 既読・削除は通知ごとの状態（[NotificationState]）で決める。
class UnreadBuilder extends StatefulWidget {
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
  State<UnreadBuilder> createState() => _UnreadBuilderState();
}

class _UnreadBuilderState extends State<UnreadBuilder> {
  late var _notificationState =
      Services.repo.watchNotificationState(widget.uid);
  late var _notifications =
      Services.repo.watchNotifications(widget.uid, widget.role);

  @override
  void didUpdateWidget(covariant UnreadBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.uid != oldWidget.uid) {
      _notificationState = Services.repo.watchNotificationState(widget.uid);
    }
    if (widget.uid != oldWidget.uid || widget.role != oldWidget.role) {
      _notifications =
          Services.repo.watchNotifications(widget.uid, widget.role);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NotificationState>(
      key: ValueKey(widget.uid),
      stream: _notificationState,
      builder: (context, state) => StreamBuilder<List<AppNotification>>(
        key: ValueKey(widget.role),
        stream: _notifications,
        builder: (context, snap) {
          final st = state.data ?? const NotificationState();
          final all = st.visible(snap.data ?? const <AppNotification>[]);
          return widget.builder(context, all, st.unread(all));
        },
      ),
    );
  }
}
