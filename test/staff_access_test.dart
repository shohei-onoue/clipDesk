import 'package:clipdesk/domain/staff_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('role の値から依頼・編集の権限を決める（未知の値は権限なし）', () {
    final both = StaffAccess.fromRole('staff', manager: true);
    expect([both.canRequest, both.canEdit, both.manager], [true, true, true]);
    expect(both.label, '編集・依頼 両方');
    final req = StaffAccess.fromRole('requester');
    expect([req.canRequest, req.canEdit, req.manager], [true, false, false]);
    expect(StaffAccess.fromRole('editor').label, '編集者');
    expect(StaffAccess.fromRole('admin').approved, isFalse);
    expect(StaffAccess.fromRole(null).label, '承認待ち');
  });

  test('保存する role の値', () {
    expect(StaffAccess.roleValue(canRequest: true, canEdit: true), 'staff');
    expect(
        StaffAccess.roleValue(canRequest: true, canEdit: false), 'requester');
    expect(StaffAccess.roleValue(canRequest: false, canEdit: true), 'editor');
    expect(StaffAccess.roleValue(canRequest: false, canEdit: false), isNull);
  });
}
