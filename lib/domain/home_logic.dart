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

/// 「新規依頼」とみなす日数。依頼した日から数えて、この日数以内なら新規。
const newRequestDays = 7;

/// 依頼から1週間以内か（暦日で数える。依頼日時が未確定のときは新規）。
bool isNewRequest(VideoRequest r, DateTime now) {
  final c = r.createdAt;
  if (c == null) return true;
  final d = DateTime(c.year, c.month, c.day);
  final n = DateTime(now.year, now.month, now.day);
  return n.difference(d).inDays <= newRequestDays;
}

/// この人が、依頼カード（依頼確認画面）を開けないか。
/// 誰でも開けるのは、バッジが「新規依頼」のカードと、まだ担当の編集者がいない受付待ちのカード。
/// 依頼主と編集担当が決まったあとは、依頼主本人と担当の編集者だけが開ける。
/// 承認待ち（動画を提出したあと、承認前）は、依頼主本人だけ。
/// 問合せ中は、依頼主本人と、問合せをした編集者だけ（それ以外は暗転して開けない）。
bool isRequestLockedFor(VideoRequest r, String? uid, DateTime now) {
  if (uid != null && r.requesterId == uid) return false;
  if (r.status == RequestStatus.needsInfo) {
    return uid == null || !r.inquirerIds.contains(uid);
  }
  // 動画を提出して承認待ちの間は、依頼主だけ（提出した編集者も開けない）。
  if (r.status == RequestStatus.review && !r.approved) return true;
  if (uid != null && r.editorId == uid) return false;
  if (r.status == RequestStatus.pending) {
    return r.editorId != null && !isNewRequest(r, now);
  }
  return true;
}

/// ダッシュボードのタブ。どの進捗の依頼かで分ける（暫定の対応。FigJamで未確定）。
/// 依頼＝受付待ち・要確認、編集＝編集中・修正、確認＝初稿確認。投稿済はライブラリで見る。
enum DashboardTab {
  all('すべて'),
  request('依頼'),
  edit('編集'),
  confirm('確認');

  const DashboardTab(this.label);
  final String label;

  /// このタブに出す進捗。Firestore の問い合わせ（サーバー側の絞り込み）に使う。
  /// [matches] と同じ内容にしておく（`all` は投稿済み以外のすべて）。
  Set<RequestStatus> get statuses => switch (this) {
        DashboardTab.all => {
            for (final s in RequestStatus.values)
              if (s != RequestStatus.posted) s
          },
        DashboardTab.request => {
            RequestStatus.pending,
            RequestStatus.needsInfo,
          },
        DashboardTab.edit => {RequestStatus.editing, RequestStatus.revision},
        DashboardTab.confirm => {RequestStatus.review},
      };

  bool matches(VideoRequest r) => switch (this) {
        DashboardTab.all => r.status != RequestStatus.posted,
        DashboardTab.request => r.status == RequestStatus.pending ||
            r.status == RequestStatus.needsInfo,
        DashboardTab.edit => r.status == RequestStatus.editing ||
            r.status == RequestStatus.revision,
        DashboardTab.confirm => r.status == RequestStatus.review,
      };

  /// 該当する依頼がないときの案内。
  String get emptyText => switch (this) {
        DashboardTab.all => '進行中の依頼はありません',
        DashboardTab.request => '受付待ち・要確認の依頼はありません',
        DashboardTab.edit => '編集中・修正の依頼はありません',
        DashboardTab.confirm => '初稿確認の依頼はありません',
      };
}

List<VideoRequest> applyDashboardTab(List<VideoRequest> all, DashboardTab t) =>
    [
      for (final r in all)
        if (t.matches(r)) r
    ];

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

/// 通知ごとの既読・削除の状態（自分の users/{uid} に持つ）。
class NotificationState {
  const NotificationState(
      {this.readIds = const {}, this.hiddenIds = const {}, this.seenAt});
  final Set<String> readIds;
  final Set<String> hiddenIds;

  /// 旧方式の「最後に通知画面を開いた時刻」。これ以前の通知は既読として扱う。
  final DateTime? seenAt;

  bool isRead(AppNotification n) =>
      readIds.contains(n.id) ||
      (seenAt != null && n.createdAt != null && !n.createdAt!.isAfter(seenAt!));

  /// 削除（非表示）していない通知。
  List<AppNotification> visible(List<AppNotification> all) => [
        for (final n in all)
          if (!hiddenIds.contains(n.id)) n
      ];

  List<AppNotification> unread(List<AppNotification> all) => [
        for (final n in all)
          if (!isRead(n)) n
      ];
}

/// 通知のタイトル。メッセージの1行目の、「：」より前（「初稿が届きました」など）。
String notificationTitle(String message) {
  final first = message.split('\n').first.trim();
  final i = first.indexOf('：');
  return i > 0 ? first.substring(0, i) : first;
}

/// 未読の通知（最後に通知画面を開いた時刻より新しいもの）。旧方式。
List<AppNotification> unreadOf(List<AppNotification> all, DateTime? seenAt) => [
      for (final n in all)
        if (seenAt == null ||
            n.createdAt == null ||
            n.createdAt!.isAfter(seenAt))
          n,
    ];

/// 通知の内容がすでに処理済みか。処理済みの通知は一覧から外し、未読として数えない。
/// 承認・取り消しの通知は「やること」が無いため、依頼の状態では判定できない
/// （ここでは false。見たかどうかは [unreadOf] で見る）。
bool isNotificationProcessed(
    AppNotification n, VideoRequest? request, String uid) {
  if (n.type == NotificationType.approved ||
      n.type == NotificationType.cancelled) {
    return false;
  }
  if (request == null) return true; // 依頼が削除された
  return switch (n.type) {
    // 他の編集者が受注した、または受付待ちでなくなった。
    NotificationType.newRequest => request.status != RequestStatus.pending ||
        (request.editorId != null && request.editorId != uid),
    NotificationType.resubmitted => request.status != RequestStatus.pending,
    NotificationType.assigned => request.status != RequestStatus.editing,
    NotificationType.reviewRequested => request.status != RequestStatus.review,
    NotificationType.revisionRequested =>
      request.status != RequestStatus.revision,
    NotificationType.needsInfo => request.status != RequestStatus.needsInfo,
    _ => false,
  };
}
