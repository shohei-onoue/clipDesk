/// スタッフの権限（roles/{uid}）。責任者が承認画面で割り当てる。
///
/// 区分は「全員が依頼も編集もできる」に統一した。承認済みのスタッフは、
/// 依頼の作成・素材のアップロード・完成品の提出・ダウンロードのすべてができる（値は `staff`）。
/// 旧データの `requester`／`editor` も、承認済み（`staff` と同じ）として扱う。
/// 責任者は別の印（`manager`）。スタッフの承認・削除ができる。
/// どの権限でも、画面は全案件を閲覧できる。
class StaffAccess {
  const StaffAccess({this.approved = false, this.manager = false});

  /// 承認前（roles/{uid} が無い）。何もできない。
  static const none = StaffAccess();

  /// 承認済み。
  final bool approved;
  final bool manager;

  /// 承認済みなら、依頼も編集もできる。
  bool get canRequest => approved;
  bool get canEdit => approved;

  /// roles/{uid} の値から作る。未知の値は権限なし（安全側）。
  factory StaffAccess.fromRole(Object? role, {Object? manager}) => StaffAccess(
        approved: role == 'staff' || role == 'requester' || role == 'editor',
        manager: manager == true,
      );

  /// 画面の表示名。
  String get label => approved ? 'スタッフ' : '承認待ち';

  /// roles/{uid} に保存する role の値。
  static const roleValue = 'staff';
}
