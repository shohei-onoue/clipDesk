import 'package:clipdesk/domain/staff_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('承認済みの role（旧データ含む）は、依頼も編集もできる。未知の値は権限なし', () {
    final both = StaffAccess.fromRole('staff', manager: true);
    expect([both.canRequest, both.canEdit, both.manager], [true, true, true]);
    expect(both.label, 'スタッフ');
    for (final old in ['requester', 'editor']) {
      final a = StaffAccess.fromRole(old);
      expect([a.canRequest, a.canEdit, a.manager], [true, true, false]);
    }
    expect(StaffAccess.fromRole('admin').approved, isFalse);
    expect(StaffAccess.fromRole(null).label, '承認待ち');
  });

  test('保存する role の値は staff 固定', () {
    expect(StaffAccess.roleValue, 'staff');
  });
}
