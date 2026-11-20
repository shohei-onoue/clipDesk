import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_tokens.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/home_logic.dart';
import '../domain/request_status.dart';
import 'status_style.dart';
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
            // 通知が1件もなければ出さない。未読がなくても、既読の通知を見る・削除するために出す。
            if (all.isEmpty) return const SizedBox.shrink();
            return _Bell(
              count: unread.length,
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => _NotificationDialog(uid: uid, role: r),
              ),
            );
          },
        );
      },
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
          label: count > 0 ? '未読の通知が$count件あります' : '通知',
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
                          size: r.x(32),
                          color: count > 0
                              ? AppColors.amber
                              : AppColors.white.withValues(alpha: 0.7)),
                    ),
                    // 右上の数字は、未読の数。
                    if (count > 0)
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
  const _NotificationDialog({required this.uid, required this.role});
  final String uid;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return UnreadBuilder(
      uid: uid,
      role: role,
      builder: (context, all, unread) {
        final unreadIds = {for (final n in unread) n.id};
        final readIds = [
          for (final n in all)
            if (!unreadIds.contains(n.id)) n.id
        ];
        TextButton action(String label, VoidCallback? onTap) => TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.white,
                disabledForegroundColor:
                    AppColors.white.withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(label, style: const TextStyle(fontSize: 12)),
            );
        return AlertDialog(
          backgroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: AppColors.white.withValues(alpha: 0.16)),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          // 右上に「すべて既読」「既読メッセージを削除」。
          title: Row(children: [
            Text('通知', style: AppText.dark(18)),
            const Spacer(),
            action(
                'すべて既読',
                unread.isEmpty
                    ? null
                    : () =>
                        Services.repo.markNotificationsRead(uid, unreadIds)),
            action(
                '既読メッセージを削除',
                readIds.isEmpty
                    ? null
                    : () => Services.repo.hideNotifications(uid, readIds)),
          ]),
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
                        // 通知された日付と、その下に通知のタイトル（表示のみ）。
                        caption: dateText(n.createdAt),
                        text: notificationTitle(n.message),
                        borderColor: fresh
                            ? AppColors.amber
                            : AppColors.white.withValues(alpha: 0.16),
                        bellColor: fresh
                            ? AppColors.amber
                            : AppColors.white.withValues(alpha: 0.7),
                        onTap: () {
                          // 通知の内容の画面へ移ると、既読にする。
                          Services.repo.markNotificationRead(uid, n.id);
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
                side:
                    BorderSide(color: AppColors.white.withValues(alpha: 0.55)),
                minimumSize: const Size(96, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }
}
