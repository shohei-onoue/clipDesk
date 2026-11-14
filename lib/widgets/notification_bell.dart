import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_tokens.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/request_status.dart';
import '../domain/video_request.dart';
import 'app_icon.dart';
import 'list_helpers.dart';
import 'notice_card.dart';
import 'unread_builder.dart';

/// アプリバーの下に置く通知アイコン。未読の通知があるときだけ出し、
/// 2件以上なら右上に件数を赤丸・白字で添える。押すと通知一覧をダイアログで開く。
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = Services.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<UserRole?>(
      stream: Services.repo.watchRole(uid),
      builder: (context, role) {
        final r = role.data;
        if (r == null) return const SizedBox.shrink();
        return UnreadBuilder(
          uid: uid,
          role: r,
          builder: (context, all, unread) {
            if (unread.isEmpty) return const SizedBox.shrink();
            return _Bell(
              count: unread.length,
              onTap: () => _open(context, uid, all, unread),
            );
          },
        );
      },
    );
  }

  /// 開いた時点の未読に【新着】の印を付けて表示し、開いたら既読にする。
  void _open(BuildContext context, String uid, List<AppNotification> all,
      List<AppNotification> unread) {
    final unreadIds = {for (final n in unread) n.id};
    Services.repo.markNotificationsSeen(uid);
    showDialog<void>(
      context: context,
      builder: (_) => _NotificationDialog(all: all, unreadIds: unreadIds),
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(right: r.x(14), top: r.x(8)),
        child: Semantics(
          button: true,
          label: count > 1 ? '通知が$count件あります' : '新しい通知があります',
          child: Tooltip(
            message: '通知',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: SizedBox(
                width: r.x(48),
                height: r.x(48),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    ExcludeSemantics(
                      child: AppIcon(AppIcons.notificationsFill,
                          size: r.x(32), color: AppColors.amber),
                    ),
                    if (count > 1)
                      Positioned(
                        right: r.x(2),
                        top: r.x(2),
                        child: Container(
                          constraints: BoxConstraints(
                              minWidth: r.x(20), minHeight: r.x(20)),
                          padding: EdgeInsets.symmetric(horizontal: r.x(5)),
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.badgeRed,
                            borderRadius: BorderRadius.all(
                                Radius.circular(AppRadius.pill)),
                          ),
                          child: Text(count > 99 ? '99+' : '$count',
                              style: AppText.noto(r.x(12),
                                  color: AppColors.white, height: 16 / 12)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationDialog extends StatelessWidget {
  const _NotificationDialog({required this.all, required this.unreadIds});
  final List<AppNotification> all;
  final Set<String> unreadIds;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return AlertDialog(
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.white.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text('通知', style: AppText.dark(18)),
      content: SizedBox(
        width: double.maxFinite,
        child: all.isEmpty
            ? emptyTextDark(context, '通知はありません')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: all.length,
                separatorBuilder: (_, __) => SizedBox(height: r.x(8)),
                itemBuilder: (context, i) {
                  final n = all[i];
                  final fresh = unreadIds.contains(n.id);
                  return NoticeCard(
                    text: fresh ? '【新着】${n.message}' : n.message,
                    borderColor: fresh
                        ? AppColors.amber
                        : AppColors.white.withValues(alpha: 0.16),
                    bellColor: fresh
                        ? AppColors.amber
                        : AppColors.white.withValues(alpha: 0.7),
                    onTap: () {
                      Navigator.of(context).pop();
                      // 取り消された依頼は削除済みで、詳細を開けない。
                      if (n.type != NotificationType.cancelled) {
                        openRequest(context, n.requestId);
                      }
                    },
                  );
                },
              ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.white,
            side: BorderSide(color: AppColors.white.withValues(alpha: 0.55)),
            minimumSize: const Size(96, 44),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
