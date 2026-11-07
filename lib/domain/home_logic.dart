import 'request_status.dart';
import 'video_request.dart';

/// 次の一手が自分にあるか（ボールが自分側にあるか）。
/// 依頼者：要確認への回答、初稿（未承認）の確認。
/// 編集者：受付待ちの確認、編集・提出、修正対応、承認済みの投稿。
bool needsMyAction(VideoRequest r, UserRole role) {
  if (role == UserRole.requester) {
    return r.status == RequestStatus.needsInfo ||
        (r.status == RequestStatus.review && !r.approved);
  }
  return r.status == RequestStatus.pending ||
      r.status == RequestStatus.editing ||
      r.status == RequestStatus.revision ||
      (r.status == RequestStatus.review && r.approved);
}

/// 自分がやること（対応待ちのときだけ）。
String? myActionLabel(VideoRequest r, UserRole role) {
  if (!needsMyAction(r, role)) return null;
  if (role == UserRole.requester) {
    return r.status == RequestStatus.needsInfo ? '指示書を直して再送信' : '初稿を確認';
  }
  return switch (r.status) {
    RequestStatus.pending => '内容を確認して編集を開始',
    RequestStatus.editing => '動画を編集して提出',
    RequestStatus.revision => '修正して動画を再提出',
    _ => '投稿して完了にする',
  };
}

/// 相手の対応待ちのときの表示。完了した依頼は null。
String? waitingLabel(VideoRequest r, UserRole role) {
  if (r.status == RequestStatus.posted || needsMyAction(r, role)) return null;
  return role == UserRole.requester ? '編集者が対応中' : '依頼者の対応待ち';
}

/// 納期までの日数（今日=0、期限超過は負）。納期なしは null。
int? daysUntilDue(DateTime? due, DateTime now) {
  if (due == null) return null;
  final d = DateTime(due.year, due.month, due.day);
  final n = DateTime(now.year, now.month, now.day);
  return d.difference(n).inDays;
}

/// ホームの絞り込み。「進行中」は投稿済を除く全件（完了は依頼確認・納品ライブラリで見る）。
enum HomeFilter {
  active('進行中'),
  mine('要対応'),
  pending('受付待ち'),
  needsInfo('要確認'),
  editing('編集中'),
  review('初稿確認'),
  revision('修正');

  const HomeFilter(this.label);
  final String label;

  RequestStatus? get status => switch (this) {
        HomeFilter.pending => RequestStatus.pending,
        HomeFilter.needsInfo => RequestStatus.needsInfo,
        HomeFilter.editing => RequestStatus.editing,
        HomeFilter.review => RequestStatus.review,
        HomeFilter.revision => RequestStatus.revision,
        _ => null,
      };

  bool matches(VideoRequest r, UserRole role) {
    if (r.status == RequestStatus.posted) return false;
    return switch (this) {
      HomeFilter.active => true,
      HomeFilter.mine => needsMyAction(r, role),
      _ => r.status == status,
    };
  }
}

List<VideoRequest> applyHomeFilter(
        List<VideoRequest> all, UserRole role, HomeFilter f) =>
    [
      for (final r in all)
        if (f.matches(r, role)) r
    ];

/// 並び順：自分の対応待ちが先、次に納期が近い順（納期なしは後ろ）、最後に新しい順。
List<VideoRequest> sortForHome(List<VideoRequest> list, UserRole role) {
  final out = [...list];
  out.sort((a, b) {
    final am = needsMyAction(a, role) ? 0 : 1;
    final bm = needsMyAction(b, role) ? 0 : 1;
    if (am != bm) return am - bm;
    final ad = a.dueDate, bd = b.dueDate;
    if (ad != null && bd != null) {
      final c = ad.compareTo(bd);
      if (c != 0) return c;
    } else if (ad != null) {
      return -1;
    } else if (bd != null) {
      return 1;
    }
    final ac = a.createdAt, bc = b.createdAt;
    if (ac != null && bc != null) return bc.compareTo(ac);
    return 0;
  });
  return out;
}

/// 未読の通知（最後に通知画面を開いた時刻より新しいもの）。
List<AppNotification> unreadOf(List<AppNotification> all, DateTime? seenAt) => [
      for (final n in all)
        if (seenAt == null ||
            n.createdAt == null ||
            n.createdAt!.isAfter(seenAt))
          n,
    ];
