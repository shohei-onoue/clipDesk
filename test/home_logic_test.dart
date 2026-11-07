import 'package:flutter_test/flutter_test.dart';

import 'package:clipdesk/domain/brief.dart';
import 'package:clipdesk/domain/home_logic.dart';
import 'package:clipdesk/domain/request_status.dart';
import 'package:clipdesk/domain/video_request.dart';

VideoRequest req(
  String id,
  RequestStatus status, {
  int? approvedVersion,
  DateTime? due,
  DateTime? createdAt,
  String? editorId,
}) =>
    VideoRequest(
      id: id,
      requesterId: 'r',
      editorId: editorId,
      status: status,
      brief: Brief.fromMap(id, const {}),
      dueDate: due,
      attachments: const [],
      reviewReason: null,
      revisionNote: null,
      submissionCount: 0,
      approvedVersion: approvedVersion,
      createdAt: createdAt,
    );

void main() {
  group('needsMyAction', () {
    test('依頼者：要確認と未承認の初稿だけ', () {
      const role = UserRole.requester;
      expect(needsMyAction(req('a', RequestStatus.needsInfo), role), isTrue);
      expect(needsMyAction(req('a', RequestStatus.review), role), isTrue);
      expect(
          needsMyAction(
              req('a', RequestStatus.review, approvedVersion: 1), role),
          isFalse);
      expect(needsMyAction(req('a', RequestStatus.pending), role), isFalse);
      expect(needsMyAction(req('a', RequestStatus.editing), role), isFalse);
      expect(needsMyAction(req('a', RequestStatus.revision), role), isFalse);
      expect(needsMyAction(req('a', RequestStatus.posted), role), isFalse);
    });

    test('編集者：受付待ち・編集中・修正・承認済み初稿', () {
      const role = UserRole.editor;
      expect(needsMyAction(req('a', RequestStatus.pending), role), isTrue);
      expect(needsMyAction(req('a', RequestStatus.editing), role), isTrue);
      expect(needsMyAction(req('a', RequestStatus.revision), role), isTrue);
      expect(
          needsMyAction(
              req('a', RequestStatus.review, approvedVersion: 1), role),
          isTrue);
      expect(needsMyAction(req('a', RequestStatus.review), role), isFalse);
      expect(needsMyAction(req('a', RequestStatus.needsInfo), role), isFalse);
      expect(needsMyAction(req('a', RequestStatus.posted), role), isFalse);
    });

    test('対応待ちならやること、そうでなければ相手待ちの表示（完了はどちらもなし）', () {
      final mine = req('a', RequestStatus.review);
      expect(myActionLabel(mine, UserRole.requester), '初稿を確認');
      expect(waitingLabel(mine, UserRole.requester), isNull);
      expect(myActionLabel(mine, UserRole.editor), isNull);
      expect(waitingLabel(mine, UserRole.editor), '依頼者の対応待ち');
      final done = req('b', RequestStatus.posted);
      expect(myActionLabel(done, UserRole.editor), isNull);
      expect(waitingLabel(done, UserRole.editor), isNull);
    });
  });

  test('daysUntilDue：今日は0、超過は負、納期なしはnull', () {
    final now = DateTime(2026, 11, 6, 20, 30);
    expect(daysUntilDue(DateTime(2026, 11, 6), now), 0);
    expect(daysUntilDue(DateTime(2026, 11, 9), now), 3);
    expect(daysUntilDue(DateTime(2026, 11, 4), now), -2);
    expect(daysUntilDue(null, now), isNull);
  });

  group('ホームの絞り込み', () {
    final all = [
      req('p', RequestStatus.pending),
      req('n', RequestStatus.needsInfo),
      req('e', RequestStatus.editing),
      req('v', RequestStatus.review),
      req('va', RequestStatus.review, approvedVersion: 2),
      req('x', RequestStatus.revision),
      req('d', RequestStatus.posted),
    ];

    List<String> ids(HomeFilter f, UserRole role) =>
        [for (final q in applyHomeFilter(all, role, f)) q.id];

    test('進行中は投稿済を除く', () {
      expect(ids(HomeFilter.active, UserRole.editor),
          ['p', 'n', 'e', 'v', 'va', 'x']);
    });

    test('要対応は役割ごと', () {
      expect(ids(HomeFilter.mine, UserRole.requester), ['n', 'v']);
      expect(ids(HomeFilter.mine, UserRole.editor), ['p', 'e', 'va', 'x']);
    });

    test('状態での絞り込み', () {
      expect(ids(HomeFilter.review, UserRole.editor), ['v', 'va']);
      expect(ids(HomeFilter.needsInfo, UserRole.requester), ['n']);
    });
  });

  test('並び順：要対応が先、次に納期が近い順、納期なしは後ろ', () {
    final list = [
      req('other-soon', RequestStatus.pending, due: DateTime(2026, 11, 7)),
      req('mine-late', RequestStatus.needsInfo, due: DateTime(2026, 11, 20)),
      req('mine-none', RequestStatus.needsInfo),
      req('mine-soon', RequestStatus.review, due: DateTime(2026, 11, 8)),
    ];
    // 依頼者：needsInfo と未承認のreviewが要対応。
    final sorted = sortForHome(list, UserRole.requester);
    expect([for (final q in sorted) q.id],
        ['mine-soon', 'mine-late', 'mine-none', 'other-soon']);
  });

  test('未読：最後に通知画面を開いた時刻より新しい通知だけ', () {
    AppNotification n(String id, DateTime? at) => AppNotification(
          id: id,
          requestId: 'r',
          type: NotificationType.newRequest,
          message: id,
          createdAt: at,
        );
    final seen = DateTime(2026, 11, 6, 12);
    final list = [
      n('new', DateTime(2026, 11, 6, 13)),
      n('old', DateTime(2026, 11, 6, 11)),
      n('pending', null),
    ];
    expect([for (final x in unreadOf(list, seen)) x.id], ['new', 'pending']);
    expect(unreadOf(list, null).length, 3);
  });
}
