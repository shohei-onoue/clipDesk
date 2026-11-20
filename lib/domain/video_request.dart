import 'package:cloud_firestore/cloud_firestore.dart';

import 'brief.dart';
import 'request_status.dart';

class Attachment {
  const Attachment({
    required this.name,
    required this.path,
    required this.size,
    required this.kind,
  });

  final String name;

  /// Storage上のパス。
  final String path;
  final int size;

  /// 'video' または 'reference'。
  final String kind;

  Map<String, Object?> toMap() =>
      {'name': name, 'path': path, 'size': size, 'kind': kind};

  factory Attachment.fromMap(Map<String, Object?> m) => Attachment(
        name: (m['name'] as String?) ?? '',
        path: (m['path'] as String?) ?? '',
        size: (m['size'] as num?)?.toInt() ?? 0,
        kind: (m['kind'] as String?) ?? 'reference',
      );
}

class Submission {
  const Submission({
    required this.version,
    required this.name,
    required this.path,
    required this.size,
    required this.createdAt,
  });

  final int version;
  final String name;
  final String path;
  final int size;
  final DateTime? createdAt;

  factory Submission.fromMap(Map<String, Object?> m) => Submission(
        version: (m['version'] as num?)?.toInt() ?? 0,
        name: (m['name'] as String?) ?? '',
        path: (m['path'] as String?) ?? '',
        size: (m['size'] as num?)?.toInt() ?? 0,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );
}

/// 問合せの履歴（編集者の問合せと、依頼者の回答）。1回の問合せ＝1件。
class Inquiry {
  const Inquiry({
    required this.round,
    required this.question,
    required this.editorName,
    required this.askedAt,
    required this.answer,
    required this.answeredAt,
  });

  final int round;
  final String question;
  final String? editorName;
  final DateTime? askedAt;

  /// 回答がまだなら null。
  final String? answer;
  final DateTime? answeredAt;

  factory Inquiry.fromMap(Map<String, Object?> m) => Inquiry(
        round: (m['round'] as num?)?.toInt() ?? 0,
        question: (m['question'] as String?) ?? '',
        editorName: m['editorName'] as String?,
        askedAt: (m['askedAt'] as Timestamp?)?.toDate(),
        answer: m['answer'] as String?,
        answeredAt: (m['answeredAt'] as Timestamp?)?.toDate(),
      );
}

class VideoRequest {
  const VideoRequest({
    required this.id,
    required this.requesterId,
    required this.editorId,
    required this.status,
    required this.brief,
    required this.dueDate,
    required this.attachments,
    required this.reviewReason,
    this.reviewRound = 0,
    required this.revisionNote,
    required this.submissionCount,
    required this.approvedVersion,
    required this.createdAt,
    this.approvedAt,
    this.editorName,
    this.inquirerIds = const [],
  });

  final String id;
  final String requesterId;
  final String? editorId;

  /// 担当編集者の名前（編集を開始した編集者のログイン名）。未記録の古い依頼は null。
  final String? editorName;

  /// 問合せをした編集者（uid）。問合せ中の依頼を開けるのは、依頼主とこの人たちだけ。
  final List<String> inquirerIds;
  final RequestStatus status;
  final Brief brief;
  final DateTime? dueDate;
  final List<Attachment> attachments;

  /// 要確認の理由。
  final String? reviewReason;

  /// 要確認（問合せ）の回数。
  final int reviewRound;

  /// 直近の修正指示。
  final String? revisionNote;
  final int submissionCount;

  /// 承認済みの動画の版。未承認は null。
  final int? approvedVersion;
  final DateTime? createdAt;

  /// 承認した日時。承認前は null。
  final DateTime? approvedAt;

  bool get approved => approvedVersion != null;

  /// 一覧・進捗用の表示ラベル。承認済みで投稿前は補足を付ける。
  String get statusLabel => status == RequestStatus.review && approved
      ? '${status.label}（承認済み・投稿待ち）'
      : status.label;

  factory VideoRequest.fromDoc(String id, Map<String, Object?> m) {
    return VideoRequest(
      id: id,
      requesterId: (m['requesterId'] as String?) ?? '',
      editorId: m['editorId'] as String?,
      status: RequestStatus.parse(m['status']) ?? RequestStatus.pending,
      brief: Brief.fromMap(
        (m['title'] as String?) ?? '',
        Map<String, Object?>.from((m['brief'] as Map?) ?? const {}),
      ),
      dueDate: (m['dueDate'] as Timestamp?)?.toDate(),
      attachments: [
        for (final a in (m['attachments'] as List?) ?? const [])
          Attachment.fromMap(Map<String, Object?>.from(a as Map)),
      ],
      reviewReason: m['reviewReason'] as String?,
      reviewRound: (m['reviewRound'] as num?)?.toInt() ?? 0,
      revisionNote: m['revisionNote'] as String?,
      submissionCount: (m['submissionCount'] as num?)?.toInt() ?? 0,
      approvedVersion: (m['approvedVersion'] as num?)?.toInt(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      approvedAt: (m['approvedAt'] as Timestamp?)?.toDate(),
      editorName: m['editorName'] as String?,
      inquirerIds: [
        for (final x in (m['inquirerIds'] as List?) ?? const [])
          if (x is String) x,
      ],
    );
  }
}

enum NotificationType {
  newRequest,
  assigned,
  reviewRequested,
  revisionRequested,
  approved,
  needsInfo,
  resubmitted,
  cancelled;

  static NotificationType? parse(Object? v) {
    for (final t in values) {
      if (t.name == v) return t;
    }
    return null;
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.requestId,
    required this.type,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String requestId;
  final NotificationType type;
  final String message;
  final DateTime? createdAt;

  factory AppNotification.fromDoc(String id, Map<String, Object?> m) =>
      AppNotification(
        id: id,
        requestId: (m['requestId'] as String?) ?? '',
        type: NotificationType.parse(m['type']) ?? NotificationType.newRequest,
        message: (m['message'] as String?) ?? '',
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );
}
