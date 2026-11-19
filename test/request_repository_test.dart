import 'dart:typed_data';

import 'package:clipdesk/data/request_repository.dart';
import 'package:clipdesk/data/storage_service.dart';
import 'package:clipdesk/domain/brief.dart';
import 'package:clipdesk/domain/request_status.dart';
import 'package:clipdesk/domain/staff_access.dart';
import 'package:clipdesk/domain/video_request.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStorage extends StorageService {
  bool fail = false;
  final saved = <String>[];
  final deleted = <String>[];
  bool failDelete = false;

  @override
  Future<bool> delete(String path) async {
    if (failDelete) return false;
    deleted.add(path);
    return true;
  }

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

  test('新規依頼の通知：全編集者に出るが、受注されたら処理済みとして全員から消える', () async {
    await create();
    Future<List<String>> types(String uid) async => [
          for (final n
              in await repo.watchNotifications(uid, UserRole.editor).first)
            n.type.name
        ];
    expect(await types('ed'), ['newRequest']);
    expect(await types('ed2'), ['newRequest']);
    await repo.startEditing(requestId: 'r1', uid: 'ed');
    // 受付待ちでなくなったので、担当の本人からも他の編集者からも消える。
    expect(await types('ed'), isEmpty);
    expect(await types('ed2'), isEmpty);
    // 依頼者には、担当が決まった通知が届く。
    final req = await repo.watchNotifications('req', UserRole.requester).first;
    expect(req.single.type.name, 'assigned');
  });

  test('添付の変更：受付待ちの本人だけ。追加・差し替え・削除でき、0件にはできない', () async {
    await create();
    final first = ((await doc())['attachments'] as List)
        .map((m) => Attachment.fromMap(Map<String, Object?>.from(m as Map)))
        .toList();
    // 追加
    await repo.updateAttachments(
        requestId: 'r1',
        uid: 'req',
        keep: first,
        add: [(file: _file('b.png'), kind: 'reference')]);
    expect(((await doc())['attachments'] as List).length, 3);
    // 差し替え（1件外して1件足す）。外したファイルはStorageからも消える。
    await repo.updateAttachments(
        requestId: 'r1',
        uid: 'req',
        keep: first.skip(1).toList(),
        add: [(file: _file('c.mp4'), kind: 'video')]);
    expect(storage.deleted, contains(first.first.path));
    // 3件のうち、残したのは1件。1件足したので、合計2件になる。
    expect(((await doc())['attachments'] as List).length, 2);
    // 0件にはできない／他人は変更できない。
    await expectLater(
        repo.updateAttachments(requestId: 'r1', uid: 'req', keep: const []),
        throwsA(isA<RequestStateException>()));
    await expectLater(
        repo.updateAttachments(requestId: 'r1', uid: 'other', keep: first),
        throwsA(isA<RequestStateException>()));
    // 受け付けられたあとは変更できない。
    await repo.startEditing(requestId: 'r1', uid: 'ed');
    await expectLater(
        repo.updateAttachments(requestId: 'r1', uid: 'req', keep: first),
        throwsA(isA<RequestStateException>()));
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
    // 新規・担当決定・初稿・修正指示・修正動画・承認
    expect((await notes()).length, 6);
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
    expect((await notes()).length, 2); // 新規依頼・担当決定のみ
  });

  test('問い合わせた編集者が担当。再送信後に再開でき、他の編集者は不可', () async {
    await create();
    await repo.askForInfo(requestId: 'r1', uid: 'ed', reason: '尺が不明');
    await expectLater(repo.askForInfo(requestId: 'r1', uid: 'ed2', reason: 'x'),
        throwsA(isA<RequestStateException>()));
    await repo.resubmitBrief(
        requestId: 'r1', uid: 'req', brief: brief, dueDate: due);
    await expectLater(repo.startEditing(requestId: 'r1', uid: 'ed2'),
        throwsA(isA<RequestStateException>()));
    await repo.startEditing(requestId: 'r1', uid: 'ed');
    expect((await doc())['editorId'], 'ed');
  });

  test('動画の提出は、編集を受けた担当の編集者だけ', () async {
    await create();
    await repo.startEditing(requestId: 'r1', uid: 'ed');
    await expectLater(
        repo.submitVideo(requestId: 'r1', uid: 'ed2', file: _file('v1.mp4')),
        throwsA(isA<RequestStateException>()));
    expect((await doc())['status'], 'editing');
    expect((await doc())['submissionCount'], 0);
    await repo.submitVideo(requestId: 'r1', uid: 'ed', file: _file('v1.mp4'));
    expect((await doc())['status'], 'review');
  });

  test('承認すると、添付素材と承認されなかった動画をStorageから消し、承認版だけ残す', () async {
    await create();
    await repo.startEditing(requestId: 'r1', uid: 'ed');
    await repo.submitVideo(requestId: 'r1', uid: 'ed', file: _file('v1.mp4'));
    await repo.requestRevision(requestId: 'r1', uid: 'req', instruction: '直して');
    await repo.submitVideo(requestId: 'r1', uid: 'ed', file: _file('v2.mp4'));
    expect(storage.deleted, isEmpty);
    expect(await repo.approve(requestId: 'r1', uid: 'req'), isTrue);
    expect(storage.deleted, hasLength(3)); // 動画・資料の添付2件＋初稿v1
    expect(storage.deleted.any((p) => p.contains('uploads/req/r1/')), isTrue);
    expect(storage.deleted.any((p) => p.contains('videos/r1/v1/')), isTrue);
    expect(storage.deleted.any((p) => p.contains('videos/r1/v2/')), isFalse);
  });

  test('削除に失敗しても承認は完了し、false を返す', () async {
    await create();
    await repo.startEditing(requestId: 'r1', uid: 'ed');
    await repo.submitVideo(requestId: 'r1', uid: 'ed', file: _file('v1.mp4'));
    storage.failDelete = true;
    expect(await repo.approve(requestId: 'r1', uid: 'req'), isFalse);
    expect((await doc())['approvedVersion'], 1);
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
    // 受付待ちの間は、依頼者が内容を何度でも直せる（編集者への通知は増えない）。
    final before = (await notes()).length;
    await repo.resubmitBrief(
        requestId: 'r1',
        uid: 'req',
        brief: brief.copyWith(deliveryTerms: '60秒・横型'),
        dueDate: due);
    expect((await doc())['brief']['deliveryTerms'], '60秒・横型');
    expect((await notes()).length, before);
    // 他人は直せない。受注された後も直せない。
    await expectLater(
        repo.resubmitBrief(
            requestId: 'r1', uid: 'other', brief: brief, dueDate: due),
        throwsA(isA<RequestStateException>()));
    await repo.startEditing(requestId: 'r1', uid: 'ed');
    await expectLater(
        repo.resubmitBrief(
            requestId: 'r1', uid: 'req', brief: brief, dueDate: due),
        throwsA(isA<RequestStateException>()));
  });

  test('依頼の取り消し：承認前は削除され、担当の編集者へ通知。他人・承認後は拒否', () async {
    await create();
    // 他人は取り消せない
    await expectLater(repo.cancelRequest(requestId: 'r1', uid: 'other'),
        throwsA(isA<RequestStateException>()));
    await repo.startEditing(requestId: 'r1', uid: 'ed');
    await repo.cancelRequest(requestId: 'r1', uid: 'req');
    expect((await db.collection('requests').doc('r1').get()).exists, isFalse);
    expect(
        (await notes())
            .any((n) => n['type'] == 'cancelled' && n['recipientId'] == 'ed'),
        isTrue);
    // 存在しない依頼
    await expectLater(repo.cancelRequest(requestId: 'r1', uid: 'req'),
        throwsA(isA<RequestStateException>()));

    // 承認後は取り消せない
    await create('r2');
    await repo.startEditing(requestId: 'r2', uid: 'ed');
    await repo.submitVideo(requestId: 'r2', uid: 'ed', file: _file('v1.mp4'));
    await repo.approve(requestId: 'r2', uid: 'req');
    await expectLater(repo.cancelRequest(requestId: 'r2', uid: 'req'),
        throwsA(isA<RequestStateException>()));
    expect((await db.collection('requests').doc('r2').get()).exists, isTrue);
  });

  test('問合せ履歴：問合せと回答を記録し、依頼を取り消すと一緒に削除される', () async {
    await create();
    await repo.askForInfo(requestId: 'r1', uid: 'ed', reason: '尺は？');
    var list = await repo.watchInquiries('r1').first;
    expect(list.length, 1);
    expect(list.first.question, '尺は？');
    expect(list.first.answer, isNull);
    await repo.resubmitBrief(
        requestId: 'r1',
        uid: 'req',
        brief: brief,
        dueDate: due,
        answer: '30秒です');
    list = await repo.watchInquiries('r1').first;
    expect(list.first.answer, '30秒です');
    await repo.cancelRequest(requestId: 'r1', uid: 'req');
    expect(
        (await db
                .collection('requests')
                .doc('r1')
                .collection('inquiries')
                .get())
            .docs,
        isEmpty);
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

  test('責任者の承認：権限を付与・変更・取り消しでき、責任者の印は別に持つ', () async {
    expect(await repo.watchAccess('u1').first, same(StaffAccess.none));
    await repo.setStaffAccess('u1',
        canRequest: false, canEdit: true, manager: false);
    var a = await repo.watchAccess('u1').first;
    expect([a.canRequest, a.canEdit, a.manager], [false, true, false]);
    await repo.setStaffAccess('u1',
        canRequest: true, canEdit: true, manager: true);
    a = await repo.watchAccess('u1').first;
    expect([a.canRequest, a.canEdit, a.manager], [true, true, true]);
    expect((await db.collection('roles').doc('u1').get()).data()!['role'],
        'staff');
    await repo.setStaffAccess('u1',
        canRequest: false, canEdit: false, manager: false);
    expect((await repo.watchAccess('u1').first).approved, isFalse);
    expect((await db.collection('roles').doc('u1').get()).exists, isFalse);
  });

  test('承認画面の一覧：登録アカウント（users）を返す', () async {
    await db.collection('users').doc('a').set({'email': 'a@x.y', 'name': 'あ'});
    final list = await repo.watchUsers().first;
    expect(list.single.email, 'a@x.y');
    expect(list.single.name, 'あ');
  });

  test('スタッフ情報の更新：姓・名を別々に保存し、name は「姓 名」で結合する', () async {
    await db
        .collection('users')
        .doc('a')
        .set({'email': 'a@x.y', 'name': '山田 太郎'});
    var u = (await repo.watchUsers().first).single;
    expect(u.nameParts, ('山田', '太郎')); // 昔の登録は名前を空白で分ける
    await repo.updateStaffProfile('a',
        lastName: '佐藤', firstName: '花子', email: 'a@x.y');
    u = (await repo.watchUsers().first).single;
    expect((u.lastName, u.firstName, u.name), ('佐藤', '花子', '佐藤 花子'));
    expect(splitName('山田　太郎'), ('山田', '太郎'));
    expect(splitName('山田'), ('山田', ''));
  });

  test('全案件：他人の依頼も一覧に出る', () async {
    await db.collection('requests').doc('x').set({
      'requesterId': 'other',
      'status': 'pending',
      'title': 't',
      'brief': {
        'title': 't',
        'purpose': 'p',
        'structure': 's',
        'deliveryTerms': 'd'
      },
    });
    expect((await repo.watchAllRequests().first).length, 1);
  });

  test('招待：保存→登録した本人が権限を受け取り、招待は消える', () async {
    await repo.saveInvite('New.User@Example.com',
        canRequest: true, canEdit: false, manager: false, invitedBy: 'mgr');
    final invites = await repo.watchInvites().first;
    expect(invites.single.email, 'new.user@example.com');
    expect(invites.single.access.label, '依頼者');

    // 招待の無いメールは何も付かない
    expect(await repo.claimInvite('u9', 'other@example.com'), isFalse);
    expect((await repo.watchAccess('u9').first).approved, isFalse);

    expect(await repo.claimInvite('u2', 'NEW.user@example.com'), isTrue);
    final a = await repo.watchAccess('u2').first;
    expect([a.canRequest, a.canEdit, a.manager], [true, false, false]);
    expect(await repo.watchInvites().first, isEmpty);
  });

  test('招待：権限を選ばないと保存できない。取消できる', () async {
    expect(
        () => repo.saveInvite('a@x.y',
            canRequest: false, canEdit: false, manager: false, invitedBy: 'm'),
        throwsArgumentError);
    await repo.saveInvite('a@x.y',
        canRequest: false, canEdit: true, manager: true, invitedBy: 'm');
    await repo.cancelInvite('A@x.y');
    expect(await repo.watchInvites().first, isEmpty);
  });
}
