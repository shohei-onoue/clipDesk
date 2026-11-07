/// スタッフの権限（roles/{uid}）。責任者が承認画面で割り当てる（暫定仕様、FigJam未確定）。
///
/// - 依頼者：依頼の作成、素材動画・画像のアップロード、完成品のダウンロード
/// - 編集者：依頼書・添付資料のダウンロード、完成品のアップロード
/// - 両方：上記すべて（値は `staff`）
/// - 責任者：上記とは別の印（`manager`）。スタッフの承認・権限変更ができる
/// どの権限でも、画面は全案件を閲覧できる。
class StaffAccess {
  const StaffAccess({
    this.canRequest = false,
    this.canEdit = false,
    this.manager = false,
  });

  /// 承認前（roles/{uid} が無い）。何もできない。
  static const none = StaffAccess();

  final bool canRequest;
  final bool canEdit;
  final bool manager;

  bool get approved => canRequest || canEdit;

  /// roles/{uid} の値から作る。未知の値は権限なし（安全側）。
  factory StaffAccess.fromRole(Object? role, {Object? manager}) => StaffAccess(
        canRequest: role == 'requester' || role == 'staff',
        canEdit: role == 'editor' || role == 'staff',
        manager: manager == true,
      );

  /// 画面の表示名。
  String get label => switch ((canRequest, canEdit)) {
        (true, true) => '編集・依頼 両方',
        (true, false) => '依頼者',
        (false, true) => '編集者',
        _ => '承認待ち',
      };

  /// roles/{uid} に保存する role の値。権限なしは null（ドキュメントを削除する）。
  static String? roleValue({required bool canRequest, required bool canEdit}) {
    if (canRequest && canEdit) return 'staff';
    if (canRequest) return 'requester';
    if (canEdit) return 'editor';
    return null;
  }
}
