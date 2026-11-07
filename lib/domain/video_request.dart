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
    required this.revisionNote,
    required this.submissionCount,
    required this.approvedVersion,
    required this.createdAt,
  });

  final String id;
  final String requesterId;
  final String? editorId;
  final RequestStatus status;
  final Brief brief;
  final DateTime? dueDate;
  final List<Attachment> attachments;

  /// 要確認の理由。
  final String? reviewReason;

  /// 直近の修正指示。
  final String? revisionNote;
  final int submissionCount;

  /// 承認済みの動画の版。未承認は null。
  final int? approvedVersion;
  final DateTime? createdAt;

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
      revisionNote: m['revisionNote'] as String?,
      submissionCount: (m['submissionCount'] as num?)?.toInt() ?? 0,
      approvedVersion: (m['approvedVersion'] as num?)?.toInt(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

enum NotificationType {
  newRequest,
  reviewRequested,
  revisionRequested,
  approved,
  needsInfo,
  resubmitted;

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
