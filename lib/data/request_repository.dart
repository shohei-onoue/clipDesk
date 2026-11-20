import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/brief.dart';
import '../domain/home_logic.dart';
import '../domain/request_status.dart';
import '../domain/staff_access.dart';
import '../domain/video_request.dart';
import 'storage_service.dart';

/// 状態が既に変わっていた等、操作を受け付けられない場合。
class RequestStateException implements Exception {
  RequestStateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 責任者の承認画面に出す、登録済みアカウント。
/// 姓と名を、表示・保存用の1つの名前（「姓 名」）にまとめる。
String joinName(String lastName, String firstName) =>
    [lastName.trim(), firstName.trim()].where((e) => e.isNotEmpty).join(' ');

/// 姓・名に分かれていない既存の名前を、最初の空白（半角・全角）で姓と名に分ける。
/// 空白が無ければ、全体を姓として返す。
(String, String) splitName(String name) {
  final t = name.trim();
  final i = t.indexOf(RegExp(r'[ \u3000]'));
  if (i < 0) return (t, '');
  return (t.substring(0, i), t.substring(i + 1).trim());
}

class StaffUser {
  const StaffUser({
    required this.uid,
    required this.email,
    required this.name,
    this.lastName = '',
    this.firstName = '',
  });
  final String uid;
  final String email;

  /// 「姓 名」を結合した表示名（昔の登録は姓名の区別なし）。
  final String name;
  final String lastName;
  final String firstName;

  /// 編集欄に出す姓・名。分かれていない昔の登録は、名前を空白で分けて出す。
  (String, String) get nameParts => lastName.isNotEmpty || firstName.isNotEmpty
      ? (lastName, firstName)
      : splitName(name);
}

/// 依頼・指示書・動画・通知の保存と状態更新。
/// 状態更新はトランザクションで「現在の状態の確認 → 更新 → 通知」を1回で行い、
/// 二重操作や保存失敗で状態と通知が食い違わないようにする。
/// 通知IDは操作ごとに決まる値にし、再実行しても重複しない。
/// 送信済みで、まだ登録されていない招待。
class Invite {
  const Invite({required this.email, required this.access});
  final String email;
  final StaffAccess access;
}

class RequestRepository {
  RequestRepository({FirebaseFirestore? db, StorageService? storage})
      : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? StorageService();

  final FirebaseFirestore _db;
  final StorageService _storage;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('requests');
  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('notifications');

  String newRequestId() => _requests.doc().id;

  // ---- 役割 ----
  /// roles/{uid} が 'staff' のスタッフが、メイン画面で選んだ立場（暫定仕様）。
  /// 依頼者・編集者のどちらにもなれる。選び直すたびにメイン画面で書き換える。
  UserRole staffMode = UserRole.requester;

  /// 'staff' は [staffMode] の立場として返す。'requester'／'editor' は従来どおり固定。
  Stream<UserRole?> watchRole(String uid) =>
      _db.collection('roles').doc(uid).snapshots().map((s) {
        final v = s.data()?['role'];
        return v == 'staff' ? staffMode : UserRole.parse(v);
      });

  // ---- スタッフの権限・承認（責任者のみ書き込み可）----
  Stream<StaffAccess> watchAccess(String uid) =>
      _db.collection('roles').doc(uid).snapshots().map((s) => s.exists
          ? StaffAccess.fromRole(s.data()?['role'],
              manager: s.data()?['manager'])
          : StaffAccess.none);

  /// 登録済みの全アカウント（承認待ちを含む）。責任者だけが読める。
  Stream<List<StaffUser>> watchUsers() =>
      _db.collection('users').snapshots().map((q) => [
            for (final d in q.docs)
              StaffUser(
                  uid: d.id,
                  email: d.data()['email'] as String? ?? '',
                  name: d.data()['name'] as String? ?? '',
                  lastName: d.data()['lastName'] as String? ?? '',
                  firstName: d.data()['firstName'] as String? ?? '')
          ]);

  /// 権限の割り当て。責任者の画面からだけ呼ぶ（ルールでも責任者以外は拒否）。
  /// 依頼者・編集者ともに false のときは承認を取り消す（roles/{uid} を削除）。
  Future<void> setStaffAccess(String uid,
      {required bool canRequest,
      required bool canEdit,
      required bool manager}) async {
    final role =
        StaffAccess.roleValue(canRequest: canRequest, canEdit: canEdit);
    final ref = _db.collection('roles').doc(uid);
    if (role == null) {
      await ref.delete();
    } else {
      await ref.set({'role': role, 'manager': manager});
    }
  }

  /// スタッフの名前・メールアドレス（users/{uid} の表示用の値）を直す。責任者だけ。
  /// 姓・名を別々に保存し、結合した name も同時に更新する。
  Future<void> updateStaffProfile(String uid,
          {required String lastName,
          required String firstName,
          required String email}) =>
      _db.collection('users').doc(uid).set({
        'lastName': lastName,
        'firstName': firstName,
        'name': joinName(lastName, firstName),
        'email': email,
      }, SetOptions(merge: true));

  /// スタッフ情報の削除：権限（roles）と登録情報（users）を消す。責任者だけ（ルールでも拒否）。
  /// 同じメールアドレスの招待が残っていれば、それも消す。
  Future<void> deleteStaff(String uid, {String email = ''}) async {
    // 権限（roles）は最後に消す。自分自身を消す場合、先に消すと以降の削除が権限エラーになる。
    if (email.trim().isNotEmpty) await cancelInvite(email);
    await _db.collection('users').doc(uid).delete();
    await _db.collection('roles').doc(uid).delete();
  }

  // ---- 招待（責任者がメールで招待 → 本人が登録フォームで登録）----
  // 招待は invites/{メールアドレス（小文字）} に権限を保存する。本人が登録すると、
  // その内容がそのまま本人の roles/{uid} になり、招待は消える。

  static String inviteId(String email) => email.trim().toLowerCase();

  Future<void> saveInvite(String email,
      {required bool canRequest,
      required bool canEdit,
      required bool manager,
      required String invitedBy}) {
    final role =
        StaffAccess.roleValue(canRequest: canRequest, canEdit: canEdit);
    if (role == null) {
      throw ArgumentError('依頼者か編集者のどちらかを選んでください');
    }
    return _db.collection('invites').doc(inviteId(email)).set({
      'role': role,
      'manager': manager,
      'invitedBy': invitedBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Invite>> watchInvites() =>
      _db.collection('invites').snapshots().map((q) => [
            for (final d in q.docs)
              Invite(
                  email: d.id,
                  access: StaffAccess.fromRole(d.data()['role'],
                      manager: d.data()['manager']))
          ]);

  Future<void> cancelInvite(String email) =>
      _db.collection('invites').doc(inviteId(email)).delete();

  /// 登録した本人が、招待された権限を自分の roles/{uid} にする（招待は削除）。
  /// 招待が無ければ何もしない（承認待ちのまま）。権限が付いたら true。
  Future<bool> claimInvite(String uid, String email) async {
    final ref = _db.collection('invites').doc(inviteId(email));
    final snap = await ref.get();
    if (!snap.exists) return false;
    final batch = _db.batch();
    batch.set(_db.collection('roles').doc(uid), {
      'role': snap.data()!['role'],
      'manager': snap.data()!['manager'] == true,
    });
    batch.delete(ref);
    await batch.commit();
    return true;
  }

  /// 全案件（スタッフは全員が閲覧できる）。
  Stream<List<VideoRequest>> watchAllRequests() =>
      _requests.snapshots().map((q) => _toRequests(q.docs));

  // ---- 通知の既読（暫定：最後に通知画面を開いた時刻）----
  // 通知ごとの既読はFigJamで未確定のため、users/{uid}.notificationsSeenAt より
  // 新しい通知を「未読」として扱う。
  Stream<DateTime?> watchNotificationsSeenAt(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((s) => (s.data()?['notificationsSeenAt'] as Timestamp?)?.toDate());

  Future<void> markNotificationsSeen(String uid) =>
      _db.collection('users').doc(uid).set(
          {'notificationsSeenAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));

  // ---- 読み取り ----

  /// スタッフの表示名。読む権限がない（自分と責任者以外）ときは null。
  Future<String?> userName(String uid) async {
    try {
      final d = await _db.collection('users').doc(uid).get();
      final name = (d.data()?['name'] as String?)?.trim();
      return name == null || name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }

  Stream<List<VideoRequest>> watchRequester(String uid) => _requests
      .where('requesterId', isEqualTo: uid)
      .snapshots()
      .map((q) => _toRequests(q.docs));

  /// 編集者: 未割り当て（受付待ち）と自分担当の依頼。
  Stream<List<VideoRequest>> watchEditor(String uid) {
    final a = _requests.where('editorId', isEqualTo: uid).snapshots();
    final b = _requests.where('editorId', isNull: true).snapshots();
    return _merge(a, b).map(_toRequests);
  }

  Stream<VideoRequest?> watchRequest(String id) => _requests
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? VideoRequest.fromDoc(s.id, s.data()!) : null);

  Stream<List<Submission>> watchSubmissions(String id) =>
      _requests.doc(id).collection('submissions').snapshots().map((q) => [
            for (final d in q.docs) Submission.fromMap(d.data())
          ]..sort((a, b) => a.version.compareTo(b.version)));

  /// 修正の依頼の内容。動画の版（提出された動画のv番号）ごとに1件。
  Stream<Map<int, String>> watchRevisions(String id) =>
      _requests.doc(id).collection('revisions').snapshots().map((q) => {
            for (final d in q.docs)
              (d.data()['version'] as num?)?.toInt() ?? 0:
                  (d.data()['instruction'] as String?) ?? ''
          });

  /// 問合せの履歴（古い順）。
  Stream<List<Inquiry>> watchInquiries(String id) =>
      _requests.doc(id).collection('inquiries').snapshots().map((q) => [
            for (final d in q.docs) Inquiry.fromMap(d.data())
          ]..sort((a, b) => a.round.compareTo(b.round)));

  /// ログイン中のユーザーの通知。自分宛て（recipientId が自分）に加え、編集者には
  /// 新規依頼の全員向け通知（audience == 'editors'）も出す。
  /// 新規依頼の通知は、他の編集者が担当になった・依頼が取り消された場合は一覧から外す。
  Stream<List<AppNotification>> watchNotifications(String uid, UserRole role) {
    final direct =
        _notifications.where('recipientId', isEqualTo: uid).snapshots();
    final merged = role == UserRole.editor
        ? _merge(direct,
            _notifications.where('audience', isEqualTo: 'editors').snapshots())
        : direct.map((q) => q.docs);
    final notes = merged.map((docs) => [
          for (final d in docs) AppNotification.fromDoc(d.id, d.data()),
        ]);
    // 依頼の今の状態を見て、処理済みの通知は一覧から外す。
    final requests =
        role == UserRole.editor ? watchAllRequests() : watchRequester(uid);
    return _combine(notes, requests, (list, requests) {
      final byId = {for (final r in requests) r.id: r};
      return _sorted([
        for (final n in list)
          if (!isNotificationProcessed(n, byId[n.requestId], uid)) n,
      ]);
    });
  }

  static List<AppNotification> _sorted(List<AppNotification> l) => l
    ..sort((a, b) => (b.createdAt ?? DateTime.now())
        .compareTo(a.createdAt ?? DateTime.now()));

  Future<String> downloadUrl(String path) => _storage.downloadUrl(path);

  Future<Uint8List> readBytes(String path) => _storage.readBytes(path);

  // ---- 依頼者: 作成・再送信 ----

  /// 依頼と指示書を保存して「受付待ち」にする。[requestId] は送信画面で1回だけ
  /// 採番し、再試行でも同じIDを使うため、二重送信しても依頼は1件になる。
  Future<void> createRequest({
    required String requestId,
    required String requesterId,
    required Brief brief,
    required DateTime dueDate,
    required List<UploadFile> videos,
    required List<UploadFile> references,
    void Function(int done, int total)? onProgress,
  }) async {
    final ref = _requests.doc(requestId);
    if ((await ref.get()).exists) return; // 送信済み（再試行）
    final attachments = await _uploadAttachments(
        requesterId, requestId, videos, references, onProgress);
    final requesterName = await _displayName(requesterId);
    final batch = _db.batch();
    batch.set(ref, {
      'requesterId': requesterId,
      if (requesterName != null) 'requesterName': requesterName,
      'editorId': null,
      'status': RequestStatus.pending.name,
      'title': brief.title.trim(),
      'brief': brief.toMap(),
      'dueDate': Timestamp.fromDate(dueDate),
      'attachments': [for (final a in attachments) a.toMap()],
      'reviewReason': null,
      'revisionNote': null,
      'reviewRound': 0,
      'submissionCount': 0,
      'approvedVersion': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // 編集者全員へ。他の編集者が担当になると、その人以外の通知一覧からは消える。
    batch.set(_notifications.doc('${requestId}_new'), {
      'requestId': requestId,
      'type': NotificationType.newRequest.name,
      'audience': 'editors',
      'recipientId': null,
      'actorId': requesterId,
      'message': '新規依頼：${brief.title.trim()}',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<List<Attachment>> _uploadAttachments(String uid, String requestId,
      List<UploadFile> videos, List<UploadFile> refs,
      [void Function(int done, int total)? onProgress]) async {
    final out = <Attachment>[];
    final total = videos.length + refs.length;
    Future<void> up(UploadFile f, String kind, int i) async {
      final path = 'uploads/$uid/$requestId/${kind}_$i-${_safe(f.name)}';
      final type =
          StorageService.contentTypeFor(f.name, video: kind == 'video');
      try {
        await _storage.upload(path, f, contentType: type);
      } catch (e) {
        // どのファイルで止まったかが分かるように、名前と種類を添える。
        throw StateError('${f.name}（$type）を保存できませんでした：$e');
      }
      out.add(Attachment(name: f.name, path: path, size: f.size, kind: kind));
      onProgress?.call(out.length, total);
    }

    for (var i = 0; i < videos.length; i++) {
      await up(videos[i], 'video', i);
    }
    for (var i = 0; i < refs.length; i++) {
      await up(refs[i], 'reference', i);
    }
    return out;
  }

  /// 受付待ちの依頼の添付を変える（依頼者本人だけ）。[keep] が変更後に残す既存の添付、
  /// [add] が新しく足すファイル。外した添付は、Storage からも消す（消せなくても変更は成立）。
  Future<void> updateAttachments({
    required String requestId,
    required String uid,
    required List<Attachment> keep,
    List<({UploadFile file, String kind})> add = const [],
  }) async {
    final ref = _requests.doc(requestId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) throw RequestStateException('依頼が見つかりません');
    if (data['requesterId'] != uid) {
      throw RequestStateException('この依頼の添付は変更できません');
    }
    final status = data['status'];
    final inReview =
        status == RequestStatus.review.name && data['approvedVersion'] == null;
    if (status != RequestStatus.pending.name && !inReview) {
      throw RequestStateException('受付待ちと、動画の確認中だけ、添付を変更できます');
    }
    if (keep.length + add.length < 1) {
      throw RequestStateException('添付は1件以上必要です。入れ替えるときは「変更」を使ってください');
    }
    final before = [
      for (final m in (data['attachments'] as List? ?? const []))
        Attachment.fromMap(Map<String, Object?>.from(m as Map))
    ];
    // 動画の確認中は、追加だけできる（これまでの添付は外せない）。
    if (inReview && keep.length != before.length) {
      throw RequestStateException('動画の確認中は、添付の追加だけできます');
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final added = <Attachment>[];
    for (var i = 0; i < add.length; i++) {
      final f = add[i].file;
      final kind = add[i].kind;
      final path = 'uploads/$uid/$requestId/${kind}_$stamp$i-${_safe(f.name)}';
      final type =
          StorageService.contentTypeFor(f.name, video: kind == 'video');
      try {
        await _storage.upload(path, f, contentType: type);
      } catch (e) {
        throw StateError('${f.name}（$type）を保存できませんでした：$e');
      }
      added.add(Attachment(name: f.name, path: path, size: f.size, kind: kind));
    }
    final next = [...keep, ...added];
    await ref.update({
      'attachments': [for (final a in next) a.toMap()],
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // 外した添付は、保存領域からも消す。消せなくても、依頼の変更は済んでいる。
    final kept = {for (final a in next) a.path};
    for (final a in before) {
      if (!kept.contains(a.path)) await _storage.delete(a.path);
    }
  }

  /// 要確認の依頼の指示書を直して再送信する。再送信後は暫定で「受付待ち」。
  Future<void> resubmitBrief({
    required String requestId,
    required String uid,
    required Brief brief,
    required DateTime dueDate,
    String? answer,
  }) async {
    // 要確認への回答のとき：回答を問合せ履歴に残し、問い合わせた編集者全員に通知する。
    final hasAnswer = answer != null && answer.trim().isNotEmpty;
    final answererName = hasAnswer ? await _displayName(uid) : null;
    var wasNeedsInfo = false;
    final asked = <String>{};
    final open = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final pre = await _requests.doc(requestId).get();
    if (pre.data()?['status'] == RequestStatus.needsInfo.name) {
      wasNeedsInfo = true;
      final all = await _requests.doc(requestId).collection('inquiries').get();
      open.addAll(all.docs.where((d) => d.data()['answer'] == null));
      open.sort((x, y) => ((x.data()['round'] as num?) ?? 0)
          .compareTo((y.data()['round'] as num?) ?? 0));
      for (final d in open) {
        final id = d.data()['editorId'] as String?;
        if (id != null) asked.add(id);
      }
    }
    await _transition(
      requestId: requestId,
      uid: uid,
      role: UserRole.requester,
      action: RequestAction.resubmit,
      update: (r) => {
        'title': brief.title.trim(),
        'brief': brief.toMap(),
        'dueDate': Timestamp.fromDate(dueDate),
        'reviewReason': null,
        if (r.inquiryFromRevision) 'inquiryFrom': null,
      },
      // 要確認への回答のときだけ通知する（受付待ちの内容編集は通知しない）。
      // 通知先は、問い合わせた編集者全員と、担当の編集者。
      extra: (tx, r) {
        if (r.status != RequestStatus.needsInfo) return;
        for (final id in {...asked, if (r.editorId != null) r.editorId!}) {
          tx.set(
              _notifications.doc('${requestId}_resubmit_${r.reviewRound}_$id'),
              {
                'requestId': requestId,
                'type': NotificationType.resubmitted.name,
                'audience': 'user',
                'recipientId': id,
                'actorId': uid,
                'message': hasAnswer
                    ? '${answererName == null ? '依頼者' : '$answererName様'}から回答がありました：${brief.title.trim()}\n${answer.trim()}'
                    : '指示書が再送信されました：${brief.title.trim()}',
                'createdAt': FieldValue.serverTimestamp(),
              });
        }
      },
    );
    // 再送信は成立している。履歴に回答を残せなかったときは、理由を伝える（黙って捨てない）。
    if (wasNeedsInfo && hasAnswer) {
      try {
        if (open.isEmpty) {
          throw StateError('回答を書き込む問合せが見つかりません');
        }
        // 回答は、まだ回答のない最新の問合せに書く。それ以前の未回答の問合せは、
        // 同じ回答でまとめて答えたものとして閉じる（回答は空。履歴には出さない）。
        final batch = _db.batch();
        for (var i = 0; i < open.length; i++) {
          final last = i == open.length - 1;
          batch.update(open[i].reference, {
            'answer': last ? answer.trim() : '',
            'answeredAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      } catch (e) {
        throw RequestStateException('回答は送信しましたが、履歴を保存できませんでした。\n$e');
      }
    }
  }

  /// 修正指示を送る（初稿確認 → 修正）。
  Future<void> requestRevision({
    required String requestId,
    required String uid,
    required String instruction,
  }) async {
    if (instruction.trim().isEmpty) {
      throw RequestStateException('修正内容を入力してください');
    }
    await _transition(
      requestId: requestId,
      uid: uid,
      role: UserRole.requester,
      action: RequestAction.requestRevision,
      update: (r) => {'revisionNote': instruction.trim()},
      extra: (tx, r) => tx.set(
        _requests
            .doc(requestId)
            .collection('revisions')
            .doc('${r.submissionCount}'),
        {
          'version': r.submissionCount,
          'instruction': instruction.trim(),
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
        },
      ),
      notification: (r) => _Notice(
        id: '${requestId}_revision_${r.submissionCount}',
        type: NotificationType.revisionRequested,
        recipientId: r.editorId,
        message: '修正指示：${r.title}\n${instruction.trim()}',
      ),
    );
  }

  /// 動画を承認する。状態は「初稿確認」のまま、承認結果だけを保存し編集者へ通知。
  /// 投稿済にはしない（投稿は編集者の操作）。
  /// 動画を承認する。承認できたら、Storageに残っている添付素材と、承認されなかった提出動画を削除し、
  /// 承認された動画だけを残す。削除に失敗したものがあれば false（承認自体は完了している）。
  Future<bool> approve({
    required String requestId,
    required String uid,
  }) async {
    await _transition(
      requestId: requestId,
      uid: uid,
      role: UserRole.requester,
      action: RequestAction.approve,
      update: (r) => {
        'approvedVersion': r.submissionCount,
        'approvedAt': FieldValue.serverTimestamp(),
      },
      notification: (r) => _Notice(
        id: '${requestId}_approved',
        type: NotificationType.approved,
        recipientId: r.editorId,
        message: '承認されました：${r.title}（投稿をお願いします）',
      ),
    );
    return _deleteUnapprovedFiles(requestId);
  }

  /// 承認後の整理：依頼時の添付素材（動画・画像・BGM・資料）と、承認されなかった提出動画を、
  /// Storage から消す。承認されなかった提出動画の記録（Firestore の submissions）も消す。
  /// Storage から消せなかった動画の記録は、あとでやり直せるように残す。
  Future<bool> _deleteUnapprovedFiles(String requestId) async {
    try {
      final snap = await _requests.doc(requestId).get();
      final data = snap.data();
      if (data == null) return false;
      final r = VideoRequest.fromDoc(snap.id, data);
      if (r.approvedVersion == null) return false;
      var ok = true;
      for (final a in r.attachments) {
        if (a.path.isNotEmpty && !await _storage.delete(a.path)) ok = false;
      }
      final unapproved = [
        for (final d
            in (await _requests.doc(requestId).collection('submissions').get())
                .docs)
          if (Submission.fromMap(d.data()).version != r.approvedVersion) d
      ];
      final batch = _db.batch();
      for (final d in unapproved) {
        final path = Submission.fromMap(d.data()).path;
        if (path.isEmpty || await _storage.delete(path)) {
          batch.delete(d.reference);
        } else {
          ok = false;
        }
      }
      await batch.commit();
      return ok;
    } catch (_) {
      return false;
    }
  }

  // ---- 編集者 ----

  /// 依頼者へ問い合わせる。問合せは担当の決定ではない（担当になるのは「受注」だけ）。
  /// 担当がいない間は、複数の編集者が続けて問い合わせられる。問合せは履歴に積み、全員が見られる。
  Future<void> askForInfo({
    required String requestId,
    required String uid,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw RequestStateException('確認したい内容（理由）を入力してください');
    }
    final name = await _displayName(uid);
    await _transition(
      requestId: requestId,
      uid: uid,
      role: UserRole.editor,
      action: RequestAction.askForInfo,
      update: (r) => {
        'reviewReason': reason.trim(),
        'reviewRound': r.reviewRound + 1,
        // 問合せ中の依頼を開けるのは、依頼主と、問合せをした編集者だけ。
        'inquirerIds': FieldValue.arrayUnion([uid]),
        // 修正の依頼への問合せは、回答のあと修正に戻す印を付ける。
        if (r.status == RequestStatus.revision) 'inquiryFrom': 'revision',
      },
      // 問合せの履歴は、状態の更新と同時に記録する（番号は更新後の回数）。
      extra: (tx, r) => tx.set(
        _requests
            .doc(requestId)
            .collection('inquiries')
            .doc('r${r.reviewRound + 1}'),
        {
          'round': r.reviewRound + 1,
          'question': reason.trim(),
          'editorId': uid,
          'editorName': name,
          'askedAt': FieldValue.serverTimestamp(),
          'answer': null,
          'answeredAt': null,
        },
      ),
      notification: (r) => _Notice(
        id: '${requestId}_needsinfo_${r.reviewRound + 1}',
        type: NotificationType.needsInfo,
        recipientId: r.requesterId,
        message: '${name ?? '編集者'}様より問合せ：${r.title}\n${reason.trim()}',
      ),
    );
  }

  /// 編集を開始する。担当編集者の決定方法は未確定のため、暫定で最初に
  /// 編集を開始した編集者を担当とする。
  Future<void> startEditing(
      {required String requestId, required String uid}) async {
    final name = await _displayName(uid);
    await _transition(
      requestId: requestId,
      uid: uid,
      role: UserRole.editor,
      action: RequestAction.startEditing,
      // 編集を開始した人のログイン名を、編集担当として残す。
      update: (r) => {'editorId': uid, if (name != null) 'editorName': name},
      // 担当が決まったことを、依頼者へ知らせる。
      notification: (r) => _Notice(
        id: '${requestId}_assigned',
        type: NotificationType.assigned,
        recipientId: r.requesterId,
        message: '担当が決まりました：${r.title}'
            '${name == null ? '' : '（担当：$name）'}',
      ),
    );
  }

  /// ログイン中のスタッフの表示名。プロフィールの名前 → 認証の表示名 → メールの順。
  Future<String?> _displayName(String uid) async {
    final profile = await userName(uid);
    if (profile != null) return profile;
    try {
      final u = FirebaseAuth.instance.currentUser;
      final n = u?.displayName?.trim();
      if (n != null && n.isNotEmpty) return n;
      final mail = u?.email;
      return mail?.split('@').first;
    } catch (_) {
      return null;
    }
  }

  /// 初稿・修正動画を保存して提出する。保存に失敗した場合は状態も通知も変えない。
  Future<void> submitVideo({
    required String requestId,
    required String uid,
    required UploadFile file,
  }) async {
    final snap = await _requests.doc(requestId).get();
    if (!snap.exists) throw RequestStateException('依頼が見つかりません');
    final cur = _Snapshot.from(snap);
    final check = nextStatus(
        current: cur.status,
        action: RequestAction.submitVideo,
        role: UserRole.editor);
    if (check == null || cur.editorId != uid) {
      throw RequestStateException('この依頼は現在、動画を提出できない状態です');
    }
    final version = cur.submissionCount + 1;
    final path = 'videos/$requestId/v$version/${_safe(file.name)}';
    await _storage.upload(path, file,
        contentType: StorageService.contentTypeFor(file.name, video: true));
    await _transition(
      requestId: requestId,
      uid: uid,
      role: UserRole.editor,
      action: RequestAction.submitVideo,
      // 保存中に別の提出が入っていないことを確認する。
      guard: (r) => r.submissionCount == cur.submissionCount,
      update: (r) => {'submissionCount': version, 'revisionNote': null},
      extra: (tx, r) => tx.set(
        _requests.doc(requestId).collection('submissions').doc('v$version'),
        {
          'version': version,
          'name': file.name,
          'path': path,
          'size': file.size,
          'uploadedBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
        },
      ),
      notification: (r) => _Notice(
        id: '${requestId}_review_$version',
        type: NotificationType.reviewRequested,
        recipientId: r.requesterId,
        message: version == 1 ? '初稿が届きました：${r.title}' : '修正動画が届きました：${r.title}',
      ),
    );
  }

  /// 承認済みの動画を「投稿済」にする。投稿先・自動投稿は未確定のため、
  /// 編集者が手動で投稿した結果を記録するだけで外部APIは呼ばない。
  Future<void> markPosted({required String requestId, required String uid}) =>
      _transition(
        requestId: requestId,
        uid: uid,
        role: UserRole.editor,
        action: RequestAction.markPosted,
        update: (r) => {'postedAt': FieldValue.serverTimestamp()},
      );

  /// 依頼者が、承認前の依頼を取り消す（完全に削除する）。元には戻せない。
  /// 提出動画・修正指示・問合せ履歴の記録も一緒に消す。担当の編集者がいれば通知する。
  /// Storage に保存した添付・動画のファイルは、ここでは消さない。
  Future<void> cancelRequest(
      {required String requestId, required String uid}) async {
    final ref = _requests.doc(requestId);
    final snap = await ref.get();
    if (!snap.exists) throw RequestStateException('依頼が見つかりません');
    final r = _Snapshot.from(snap);
    if (r.requesterId != uid) {
      throw RequestStateException('依頼者本人だけが取り消せます');
    }
    if (r.status == RequestStatus.posted || r.approvedVersion != null) {
      throw RequestStateException('承認後の依頼は取り消せません');
    }
    final subs = await ref.collection('submissions').get();
    final revs = await ref.collection('revisions').get();
    // 問合せ履歴も一緒に消す。読めない（記録がない）場合は、消すものがないものとして進める。
    var inquiries = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    try {
      inquiries = (await ref.collection('inquiries').get()).docs;
    } catch (_) {}
    final batch = _db.batch();
    for (final d in [...subs.docs, ...revs.docs, ...inquiries]) {
      batch.delete(d.reference);
    }
    batch.delete(ref);
    final editor = r.editorId;
    if (editor != null) {
      batch.set(_notifications.doc('${requestId}_cancelled'), {
        'requestId': requestId,
        'type': NotificationType.cancelled.name,
        'audience': 'user',
        'recipientId': editor,
        'actorId': uid,
        'message': '依頼が取り消されました：${r.title}',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // ---- 共通 ----

  Future<void> _transition({
    required String requestId,
    required String uid,
    required UserRole role,
    required RequestAction action,
    required Map<String, Object?> Function(_Snapshot) update,
    bool Function(_Snapshot)? guard,
    void Function(Transaction, _Snapshot)? extra,
    _Notice? Function(_Snapshot)? notification,
  }) {
    return _db.runTransaction((tx) async {
      final ref = _requests.doc(requestId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw RequestStateException('依頼が見つかりません');
      final r = _Snapshot.from(snap);
      final owner = role == UserRole.requester
          ? r.requesterId == uid
          : (r.editorId == uid ||
              (r.editorId == null &&
                  (action == RequestAction.startEditing ||
                      action == RequestAction.askForInfo)));
      final next = nextStatus(
          current: r.status,
          action: action,
          role: role,
          approved: r.approvedVersion != null,
          inquiryFromRevision: r.inquiryFromRevision);
      if (!owner || next == null || (guard != null && !guard(r))) {
        throw RequestStateException('依頼の状態が変わっています。画面を更新して確認してください');
      }
      tx.update(ref, {
        ...update(r),
        'status': next.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      extra?.call(tx, r);
      final n = notification?.call(r);
      if (n != null) {
        tx.set(_notifications.doc(n.id), {
          'requestId': requestId,
          'type': n.type.name,
          'audience': 'user',
          'recipientId': n.recipientId,
          'actorId': uid,
          'message': n.message,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  static List<VideoRequest> _toRequests(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final list = [for (final d in docs) VideoRequest.fromDoc(d.id, d.data())];
    list.sort((a, b) => (b.createdAt ?? DateTime.now())
        .compareTo(a.createdAt ?? DateTime.now()));
    return list;
  }

  static String _safe(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}

class _Notice {
  _Notice({
    required this.id,
    required this.type,
    required this.message,
    this.recipientId,
  });
  final String id;
  final NotificationType type;
  final String message;
  final String? recipientId;
}

class _Snapshot {
  _Snapshot.from(DocumentSnapshot<Map<String, dynamic>> s)
      : status =
            RequestStatus.parse(s.data()!['status']) ?? RequestStatus.pending,
        requesterId = (s.data()!['requesterId'] as String?) ?? '',
        editorId = s.data()!['editorId'] as String?,
        title = (s.data()!['title'] as String?) ?? '',
        submissionCount = (s.data()!['submissionCount'] as num?)?.toInt() ?? 0,
        approvedVersion = (s.data()!['approvedVersion'] as num?)?.toInt(),
        reviewRound = (s.data()!['reviewRound'] as num?)?.toInt() ?? 0,
        inquiryFromRevision = s.data()!['inquiryFrom'] == 'revision';

  final RequestStatus status;
  final String requesterId;
  final String? editorId;
  final String title;
  final int submissionCount;
  final int? approvedVersion;
  final int reviewRound;
  final bool inquiryFromRevision;
}

/// 2つのクエリ購読を結合し、どちらかが更新されるたびに重複なしで流す。
Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _merge(
  Stream<QuerySnapshot<Map<String, dynamic>>> a,
  Stream<QuerySnapshot<Map<String, dynamic>>> b,
) {
  late StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>> c;
  final subs = <StreamSubscription<Object?>>[];
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? la, lb;
  void emit() {
    if (la == null || lb == null) return;
    final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
      for (final d in [...la!, ...lb!]) d.id: d,
    };
    c.add(byId.values.toList());
  }

  c = StreamController(
    onListen: () {
      subs.add(a.listen((q) {
        la = q.docs;
        emit();
      }, onError: c.addError));
      subs.add(b.listen((q) {
        lb = q.docs;
        emit();
      }, onError: c.addError));
    },
    onCancel: () async {
      for (final s in subs) {
        await s.cancel();
      }
    },
  );
  return c.stream;
}

/// 2つのストリームの最新値を組み合わせる。両方に値が来てから、どちらかが変わるたびに流す。
Stream<R> _combine<A, B, R>(Stream<A> a, Stream<B> b, R Function(A, B) f) {
  late StreamController<R> c;
  final subs = <StreamSubscription<Object?>>[];
  A? la;
  B? lb;
  var ha = false, hb = false;
  void emit() {
    if (ha && hb) c.add(f(la as A, lb as B));
  }

  c = StreamController(
    onListen: () {
      subs.add(a.listen((v) {
        la = v;
        ha = true;
        emit();
      }, onError: c.addError));
      subs.add(b.listen((v) {
        lb = v;
        hb = true;
        emit();
      }, onError: c.addError));
    },
    onCancel: () async {
      for (final s in subs) {
        await s.cancel();
      }
    },
  );
  return c.stream;
}
