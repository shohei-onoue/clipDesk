import 'dart:typed_data';

import 'package:clipdesk/data/request_repository.dart';
import 'package:clipdesk/data/storage_service.dart';
import 'package:clipdesk/domain/brief.dart';
import 'package:clipdesk/domain/request_status.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStorage extends StorageService {
  bool fail = false;
  final saved = <String>[];

  @override
  Future<void> upload(String path, UploadFile file,
      {required String contentType}) async {
    if (fail) throw StateError('network');
    saved.add(path);
  }
}

UploadFile _file(String n) =>
    UploadFile(name: n, size: 3, read: () async => Uint8List(3));

void main() {
  late FakeFirebaseFirestore db;
  late _FakeStorage storage;
  late RequestRepository repo;
  const brief = Brief(
      title: '新商品紹介',
      purpose: '認知拡大',
      structure: '紹介→購入案内',
      deliveryTerms: '30秒',
      scenes: [Scene(title: '冒頭', instruction: '商品を大写し')]);
  final due = DateTime(2026, 12, 1);

  setUp(() {
    db = FakeFirebaseFirestore();
    storage = _FakeStorage();
    repo = RequestRepository(db: db, storage: storage);
  });

  Future<void> create([String id = 'r1']) => repo.createRequest(
      requestId: id,
      requesterId: 'req',
      brief: brief,
      dueDate: due,
      videos: [_file('a.mp4')],
      references: [_file('ref.pdf')]);

  Future<Map<String, dynamic>> doc([String id = 'r1']) async =>
      (await db.collection('requests').doc(id).get()).data()!;
  Future<List<Map<String, dynamic>>> notes() async =>
      (await db.collection('notifications').get())
          .docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList();

  test('依頼作成: 受付待ち・指示書と添付を保存し、編集者へ新規依頼通知', () async {
    await create();
    final d = await doc();
    expect(d['status'], 'pending');
    expect(d['brief']['purpose'], '認知拡大');
    expect((d['brief']['scenes'] as List).length, 1);
    expect((d['attachments'] as List).length, 2);
    final n = await notes();
    expect(n.single['type'], 'newRequest');
    expect(n.single['audience'], 'editors');
  });

  test('二重送信しても依頼と通知は1件', () async {
    await Future.wait([create(), create()]);
    await create();
    expect((await db.collection('requests').get()).docs.length, 1);
    expect((await notes()).length, 1);
  });

  test('添付の保存に失敗したら依頼も通知も作られず、再試行できる', () async {
    storage.fail = true;
    await expectLater(create(), throwsA(isA<StateError>()));
    expect((await db.collection('requests').get()).docs, isEmpty);
    expect(await notes(), isEmpty);
    storage.fail = false;
    await create();
    expect((await doc())['status'], 'pending');
  });

  test('フロー全体: 初稿→修正→再提出→承認→投稿済', () async {
    await create();
    await repo.startEditing(requestId: 'r1', uid: 'ed');
    expect((await doc())['status'], 'editing');
    expect((await doc())['editorId'], 'ed');

    await repo.submitVideo(requestId: 'r1', uid: 'ed', file: _file('v1.mp4'));
    expect((await doc())['status'], 'review');
    expect((await doc())['submissionCount'], 1);

    await repo.requestRevision(
        requestId: 'r1', uid: 'req', instruction: 'テロップを大きく');
    expect((await doc())['status'], 'revision');
    expect((await doc())['revisionNote'], 'テロップを大きく');

    await repo.submitVideo(requestId: 'r1', uid: 'ed', file: _file('v2.mp4'));
    expect((await doc())['submissionCount'], 2);
    expect((await doc())['revisionNote'], isNull);

    await repo.approve(requestId: 'r1', uid: 'req');
    var d = await doc();
    expect(d['status'], 'review'); // 承認だけでは投稿済にならない
    expect(d['approvedVersion'], 2);

    await repo.markPosted(requestId: 'r1', uid: 'ed');
    d = await doc();
    expect(d['status'], 'posted');

    final n = {for (final x in await notes()) x['type'] as String: x};
    expect(n['reviewRequested'], isNotNull);
    expect(n['revisionRequested']!['recipientId'], 'ed');
    expect(n['approved']!['recipientId'], 'ed');
    expect(n['reviewRequested']!['recipientId'], 'req');
    // 新規1 + 初稿1 + 修正指示1 + 修正動画1 + 承認1
    expect((await notes()).length, 5);
  });

  test('動画の保存に失敗したら、初稿確認にも通知にも提出記録にもならない', () async {
    await create();
    await repo.startEditing(requestId: 'r1', uid: 'ed');
    storage.fail = true;
    await expectLater(
        repo.submitVideo(requestId: 'r1', uid: 'ed', file: _file('v1.mp4')),
        throwsA(isA<StateError>()));
    expect((await doc())['status'], 'editing');
    expect((await doc())['submissionCount'], 0);
    expect(
        (await db
                .collection('requests')
                .doc('r1')
                .collection('submissions')
                .get())
            .docs,
        isEmpty);
    expect((await notes()).length, 1); // 新規依頼の通知のみ
  });

  test('二重操作: 2回目は拒否され、通知も重複しない', () async {
    await create();
    await repo.startEditing(requestId: 'r1', uid: 'ed');
    await expectLater(repo.startEditing(requestId: 'r1', uid: 'ed2'),
        throwsA(isA<RequestStateException>()));
    expect((await doc())['editorId'], 'ed');

    await repo.submitVideo(requestId: 'r1', uid: 'ed', file: _file('v1.mp4'));
    await expectLater(
        repo.submitVideo(requestId: 'r1', uid: 'ed', file: _file('v1.mp4')),
        throwsA(isA<RequestStateException>()));
    await repo.approve(requestId: 'r1', uid: 'req');
    await expectLater(repo.approve(requestId: 'r1', uid: 'req'),
        throwsA(isA<RequestStateException>()));
    expect((await notes()).where((n) => n['type'] == 'approved').length, 1);
    expect(
        (await notes()).where((n) => n['type'] == 'reviewRequested').length, 1);
  });

  test('関係のない利用者・誤った順序の操作は拒否', () async {
    await create();
    await expectLater(repo.approve(requestId: 'r1', uid: 'req'),
        throwsA(isA<RequestStateException>())); // まだ初稿確認ではない
    await repo.startEditing(requestId: 'r1', uid: 'ed');
    await expectLater(
        repo.submitVideo(requestId: 'r1', uid: 'other', file: _file('x.mp4')),
        throwsA(isA<RequestStateException>()));
    await repo.submitVideo(requestId: 'r1', uid: 'ed', file: _file('v1.mp4'));
    await expectLater(repo.approve(requestId: 'r1', uid: 'stranger'),
        throwsA(isA<RequestStateException>()));
    await expectLater(repo.markPosted(requestId: 'r1', uid: 'ed'),
        throwsA(isA<RequestStateException>())); // 未承認
    await repo.approve(requestId: 'r1', uid: 'req');
    await expectLater(
        repo.requestRevision(requestId: 'r1', uid: 'req', instruction: 'x'),
        throwsA(isA<RequestStateException>())); // 承認後は修正不可
  });

  test('要確認: 理由必須→依頼者が指示書を直して再送信→受付待ち', () async {
    await create();
    await expectLater(repo.askForInfo(requestId: 'r1', uid: 'ed', reason: ' '),
        throwsA(isA<RequestStateException>()));
    await repo.askForInfo(requestId: 'r1', uid: 'ed', reason: '尺が不明');
    var d = await doc();
    expect(d['status'], 'needsInfo');
    expect(d['reviewReason'], '尺が不明');
    expect(
        (await notes())
            .any((n) => n['type'] == 'needsInfo' && n['recipientId'] == 'req'),
        isTrue);

    await repo.resubmitBrief(
        requestId: 'r1',
        uid: 'req',
        brief: brief.copyWith(deliveryTerms: '30秒・縦型'),
        dueDate: due);
    d = await doc();
    expect(d['status'], 'pending');
    expect(d['brief']['deliveryTerms'], '30秒・縦型');
    expect(d['reviewReason'], isNull);
    // 再送信後の再実行は拒否される
    await expectLater(
        repo.resubmitBrief(
            requestId: 'r1', uid: 'req', brief: brief, dueDate: due),
        throwsA(isA<RequestStateException>()));
  });

  test('2回目の要確認でも通知は別IDで作られる', () async {
    await create();
    await repo.askForInfo(requestId: 'r1', uid: 'ed', reason: 'a');
    await repo.resubmitBrief(
        requestId: 'r1', uid: 'req', brief: brief, dueDate: due);
    await repo.askForInfo(requestId: 'r1', uid: 'ed', reason: 'b');
    expect((await notes()).where((n) => n['type'] == 'needsInfo').length, 2);
  });

  test('通知の既読：最後に開いた時刻を users/{uid} に保存し、役割は書き換えない', () async {
    expect(await repo.watchNotificationsSeenAt('u1').first, isNull);
    await repo.markNotificationsSeen('u1');
    expect(await repo.watchNotificationsSeenAt('u1').first, isNotNull);
    final doc = await db.collection('users').doc('u1').get();
    expect(doc.data()!.containsKey('role'), isFalse);
  });

  test("役割 'staff' は、メイン画面で選んだ立場として返る（固定役割はそのまま）", () async {
    await db.collection('roles').doc('s1').set({'role': 'staff'});
    await db.collection('roles').doc('e1').set({'role': 'editor'});
    expect(await repo.watchRole('s1').first, UserRole.requester);
    repo.staffMode = UserRole.editor;
    expect(await repo.watchRole('s1').first, UserRole.editor);
    repo.staffMode = UserRole.requester;
    expect(await repo.watchRole('e1').first, UserRole.editor);
    expect(await repo.watchRole('none').first, isNull);
  });
}
