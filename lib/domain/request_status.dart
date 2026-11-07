/// 利用者の役割（画面・操作の立場）。roles/{uid} が 'staff' のスタッフは、
/// メイン画面で選んだ立場（依頼者／編集者）で動く。
/// 利用者の役割。付与方法はFigJamで未確定のため、Firestoreの roles/{uid} を
/// 管理者（Firebaseコンソール等）が設定する暫定方式とし、アプリからは書き換えない。
enum UserRole {
  requester,
  editor;

  static UserRole? parse(Object? v) {
    for (final r in values) {
      if (r.name == v) return r;
    }
    return null;
  }
}

/// 進捗（FigJam「受付待ち／要確認／編集中／初稿確認／修正／投稿済」）。
/// 「要確認」「修正」は分岐であり、必ず通過する段階ではない。
enum RequestStatus {
  pending('受付待ち'),
  needsInfo('要確認'),
  editing('編集中'),
  review('初稿確認'),
  revision('修正'),
  posted('投稿済');

  const RequestStatus(this.label);
  final String label;

  static RequestStatus? parse(Object? v) {
    for (final s in values) {
      if (s.name == v) return s;
    }
    return null;
  }
}

/// 状態を変える操作。
enum RequestAction {
  /// 編集者: 不明点を理由付きで差し戻す。
  askForInfo,

  /// 編集者: 編集を開始する。
  startEditing,

  /// 依頼者: 指示書を直して再送信する（再送信後は暫定で受付待ち）。
  resubmit,

  /// 編集者: 初稿・修正動画を提出する。
  submitVideo,

  /// 依頼者: 修正指示を送る。
  requestRevision,

  /// 依頼者: 動画を承認する（状態は変えず承認結果だけ保存）。
  approve,

  /// 編集者: 承認済みの動画を投稿済にする。
  markPosted,
}

class TransitionResult {
  const TransitionResult(this.next);
  final RequestStatus next;
}

/// 操作の実行可否と遷移先。許可されない場合は null。
/// [approved] は承認結果が保存済みかどうか。
RequestStatus? nextStatus({
  required RequestStatus current,
  required RequestAction action,
  required UserRole role,
  bool approved = false,
}) {
  switch (action) {
    case RequestAction.askForInfo:
      if (role == UserRole.editor &&
          (current == RequestStatus.pending ||
              current == RequestStatus.editing)) {
        return RequestStatus.needsInfo;
      }
    case RequestAction.startEditing:
      if (role == UserRole.editor && current == RequestStatus.pending) {
        return RequestStatus.editing;
      }
    case RequestAction.resubmit:
      if (role == UserRole.requester && current == RequestStatus.needsInfo) {
        return RequestStatus.pending;
      }
    case RequestAction.submitVideo:
      if (role == UserRole.editor &&
          (current == RequestStatus.editing ||
              current == RequestStatus.revision)) {
        return RequestStatus.review;
      }
    case RequestAction.requestRevision:
      if (role == UserRole.requester &&
          current == RequestStatus.review &&
          !approved) {
        return RequestStatus.revision;
      }
    case RequestAction.approve:
      if (role == UserRole.requester &&
          current == RequestStatus.review &&
          !approved) {
        return RequestStatus.review;
      }
    case RequestAction.markPosted:
      if (role == UserRole.editor &&
          current == RequestStatus.review &&
          approved) {
        return RequestStatus.posted;
      }
  }
  return null;
}
