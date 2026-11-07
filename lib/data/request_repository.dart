import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/brief.dart';
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
class StaffUser {
  const StaffUser({required this.uid, required this.email, required this.name});
  final String uid;
  final String email;
  final String name;
}

/// 依頼・指示書・動画・通知の保存と状態更新。
/// 状態更新はトランザクションで「現在の状態の確認 → 更新 → 通知」を1回で行い、
/// 二重操作や保存失敗で状態と通知が食い違わないようにする。
/// 通知IDは操作ごとに決まる値にし、再実行しても重複しない。
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
                  name: d.data()['name'] as String? ?? '')
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

  Stream<List<AppNotification>> watchNotifications(String uid, UserRole role) {
    final direct =
        _notifications.where('recipientId', isEqualTo: uid).snapshots();
    final merged = role == UserRole.editor
        ? _merge(direct,
            _notifications.where('audience', isEqualTo: 'editors').snapshots())
        : direct.map((q) => q.docs);
    return merged.map((docs) {
      final list = [
        for (final d in docs) AppNotification.fromDoc(d.id, d.data()),
      ]..sort((a, b) => (b.createdAt ?? DateTime.now())
          .compareTo(a.createdAt ?? DateTime.now()));
      return list;
    });
  }

  Future<String> downloadUrl(String path) => _storage.downloadUrl(path);

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
  }) async {
    final ref = _requests.doc(requestId);
    if ((await ref.get()).exists) return; // 送信済み（再試行）
    final attachments =
        await _uploadAttachments(requesterId, requestId, videos, references);
    final batch = _db.batch();
    batch.set(ref, {
      'requesterId': requesterId,
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
      List<UploadFile> videos, List<UploadFile> refs) async {
    final out = <Attachment>[];
    Future<void> up(UploadFile f, String kind, int i) async {
      final path = 'uploads/$uid/$requestId/${kind}_$i-${_safe(f.name)}';
      await _storage.upload(path, f,
          contentType:
              StorageService.contentTypeFor(f.name, video: kind == 'video'));
      out.add(Attachment(name: f.name, path: path, size: f.size, kind: kind));
    }

    for (var i = 0; i < videos.length; i++) {
      await up(videos[i], 'video', i);
    }
    for (var i = 0; i < refs.length; i++) {
      await up(refs[i], 'reference', i);
    }
    return out;
  }

  /// 要確認の依頼の指示書を直して再送信する。再送信後は暫定で「受付待ち」。
  Future<void> resubmitBrief({
    required String requestId,
    required String uid,
    required Brief brief,
    required DateTime dueDate,
  }) =>
      _transition(
        requestId: requestId,
        uid: uid,
        role: UserRole.requester,
        action: RequestAction.resubmit,
        update: (r) => {
          'title': brief.title.trim(),
          'brief': brief.toMap(),
          'dueDate': Timestamp.fromDate(dueDate),
          'reviewReason': null,
        },
        notification: (r) => _Notice(
          id: '${requestId}_resubmit_${r.reviewRound}',
          type: NotificationType.resubmitted,
          recipientId: r.editorId,
          audience: r.editorId == null ? 'editors' : null,
          message: '指示書が再送信されました：${brief.title.trim()}',
        ),
      );

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
  Future<void> approve({
    required String requestId,
    required String uid,
  }) =>
      _transition(
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

  // ---- 編集者 ----

  Future<void> askForInfo({
    required String requestId,
    required String uid,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw RequestStateException('確認したい内容（理由）を入力してください');
    }
    await _transition(
      requestId: requestId,
      uid: uid,
      role: UserRole.editor,
      action: RequestAction.askForInfo,
      update: (r) => {
        'reviewReason': reason.trim(),
        'editorId': r.editorId ?? uid,
        'reviewRound': r.reviewRound + 1,
      },
      notification: (r) => _Notice(
        id: '${requestId}_needsinfo_${r.reviewRound + 1}',
        type: NotificationType.needsInfo,
        recipientId: r.requesterId,
        message: '要確認：${r.title}\n${reason.trim()}',
      ),
    );
  }

  /// 編集を開始する。担当編集者の決定方法は未確定のため、暫定で最初に
  /// 編集を開始した編集者を担当とする。
  Future<void> startEditing({required String requestId, required String uid}) =>
      _transition(
        requestId: requestId,
        uid: uid,
        role: UserRole.editor,
        action: RequestAction.startEditing,
        update: (r) => {'editorId': uid},
      );

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

  // ---- 共通 ----

  Future<void> _transition({
    required String requestId,
    required String uid,
    required UserRole role,
    required RequestAction action,
    required Map<String, Object?> Function(_Snapshot) update,
    bool Function(_Snapshot)? guard,
    void Function(Transaction, _Snapshot)? extra,
    _Notice Function(_Snapshot)? notification,
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
          approved: r.approvedVersion != null);
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
          'audience': n.audience ?? 'user',
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
    this.audience,
  });
  final String id;
  final NotificationType type;
  final String message;
  final String? recipientId;
  final String? audience;
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
        reviewRound = (s.data()!['reviewRound'] as num?)?.toInt() ?? 0;

  final RequestStatus status;
  final String requesterId;
  final String? editorId;
  final String title;
  final int submissionCount;
  final int? approvedVersion;
  final int reviewRound;
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
