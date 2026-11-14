import 'package:clipdesk/domain/brief.dart';
import 'package:clipdesk/domain/request_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RequestStatus? go(RequestStatus s, RequestAction a, UserRole r,
          {bool approved = false}) =>
      nextStatus(current: s, action: a, role: r, approved: approved);

  group('状態遷移', () {
    test('FigJamの流れ: 受付待ち→編集中→初稿確認→(承認)→投稿済', () {
      expect(
          go(RequestStatus.pending, RequestAction.startEditing,
              UserRole.editor),
          RequestStatus.editing);
      expect(
          go(RequestStatus.editing, RequestAction.submitVideo, UserRole.editor),
          RequestStatus.review);
      // 承認しても状態は初稿確認のまま（自動で投稿済にしない）
      expect(
          go(RequestStatus.review, RequestAction.approve, UserRole.requester),
          RequestStatus.review);
      expect(
          go(RequestStatus.review, RequestAction.markPosted, UserRole.editor,
              approved: true),
          RequestStatus.posted);
    });

    test('要確認と修正は分岐', () {
      expect(
          go(RequestStatus.pending, RequestAction.askForInfo, UserRole.editor),
          RequestStatus.needsInfo);
      expect(
          go(RequestStatus.needsInfo, RequestAction.resubmit,
              UserRole.requester),
          RequestStatus.pending);
      expect(
          go(RequestStatus.review, RequestAction.requestRevision,
              UserRole.requester),
          RequestStatus.revision);
      expect(
          go(RequestStatus.revision, RequestAction.submitVideo,
              UserRole.editor),
          RequestStatus.review);
    });

    test('承認前は投稿済にできない／承認後は修正できない', () {
      expect(
          go(RequestStatus.review, RequestAction.markPosted, UserRole.editor),
          isNull);
      expect(
          go(RequestStatus.review, RequestAction.requestRevision,
              UserRole.requester,
              approved: true),
          isNull);
      expect(
          go(RequestStatus.review, RequestAction.approve, UserRole.requester,
              approved: true),
          isNull);
    });

    test('役割違い・状態違いは拒否', () {
      expect(
          go(RequestStatus.pending, RequestAction.startEditing,
              UserRole.requester),
          isNull);
      expect(go(RequestStatus.review, RequestAction.approve, UserRole.editor),
          isNull);
      expect(
          go(RequestStatus.editing, RequestAction.startEditing,
              UserRole.editor),
          isNull);
      expect(
          go(RequestStatus.posted, RequestAction.submitVideo, UserRole.editor),
          isNull);
      expect(
          go(RequestStatus.editing, RequestAction.approve, UserRole.requester),
          isNull);
    });
  });

  group('指示書の検証', () {
    final now = DateTime(2026, 11, 6, 15);
    const ok =
        Brief(title: 't', purpose: 'p', structure: 's', deliveryTerms: 'd');

    test('揃っていればエラーなし（当日の納期も可）', () {
      expect(
          BriefValidation.validate(
              brief: ok,
              dueDate: DateTime(2026, 11, 6),
              attachmentCount: 1,
              now: now),
          isEmpty);
    });

    test('必須項目・動画・納期の不足を検出', () {
      final e = BriefValidation.validate(
          brief: const Brief(title: ' '),
          dueDate: null,
          attachmentCount: 0,
          now: now);
      expect(
          e.keys,
          containsAll(
              ['title', 'purpose', 'deliveryTerms', 'video', 'dueDate']));
    });

    test('過去の納期は不可', () {
      final e = BriefValidation.validate(
          brief: ok,
          dueDate: DateTime(2026, 11, 5),
          attachmentCount: 1,
          now: now);
      expect(e.keys, ['dueDate']);
    });
  });
}
