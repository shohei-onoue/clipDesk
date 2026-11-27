import 'package:clipdesk/data/request_repository.dart';
import 'package:clipdesk/data/services.dart';
import 'package:clipdesk/data/storage_service.dart';
import 'package:clipdesk/screens/staff_admin_screen.dart';
import 'package:clipdesk/widgets/ruby_text.dart' as ruby;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() async {
    db = FakeFirebaseFirestore();
    Services.repo = RequestRepository(db: db, storage: StorageService());
    Services.uidOverride = 'u1';
    for (final u in [('u1', '依頼 太郎', true), ('e1', '編集 花子', false)]) {
      await db
          .collection('roles')
          .doc(u.$1)
          .set({'role': 'staff', 'manager': u.$3});
      await db
          .collection('users')
          .doc(u.$1)
          .set({'name': u.$2, 'email': '${u.$1}@example.com'});
    }
  });

  tearDown(() => Services.uidOverride = null);

  Finder label(String text) =>
      find.byWidgetPredicate((w) => w is ruby.Text && w.data == text,
          description: text);

  Future<void> open(WidgetTester t, String name) async {
    await t.pumpWidget(const MaterialApp(home: StaffAdminScreen()));
    await t.pumpAndSettle();
    await t.drag(label(name), const Offset(-300, 0));
    await t.pumpAndSettle();
  }

  /// 開いたカードの「削除」ボタン（閉じたカードのボタンは、押せないので除く）。
  Finder delete() => label('削除').hitTestable();

  Future<bool> exists(String uid) async =>
      (await db.collection('users').doc(uid).get()).exists &&
      (await db.collection('roles').doc(uid).get()).exists;

  testWidgets('ほかのスタッフのカードには、編集ボタンがない', (t) async {
    await open(t, '編集 花子');
    expect(label('編集').hitTestable(), findsNothing);
    expect(delete(), findsOneWidget);
  });

  testWidgets('自分のカードは編集できる', (t) async {
    await open(t, '依頼 太郎');
    await t.tap(label('編集').hitTestable());
    await t.pumpAndSettle();
    expect(label('スタッフ情報を編集'), findsOneWidget);
    expect(label('パスワードの変更（変えない場合は空欄）'), findsOneWidget);
  });

  testWidgets('削除は5秒の長押し。途中で離すと削除せず、案内を出す', (t) async {
    await open(t, '編集 花子');
    final g = await t.startGesture(t.getCenter(delete()));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('このまま押し続けると'), findsOneWidget);
    await g.up();
    await t.pump(const Duration(seconds: 6));
    expect(await exists('e1'), isTrue);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('長押しするとスタッフ情報を削除します'), findsOneWidget);
  });

  testWidgets('押したまま指を動かすと、削除しない', (t) async {
    await open(t, '編集 花子');
    final g = await t.startGesture(t.getCenter(delete()));
    await t.pump(const Duration(seconds: 2));
    await g.moveBy(const Offset(0, -60));
    await t.pump(const Duration(seconds: 6));
    await g.up();
    await t.pumpAndSettle();
    expect(find.textContaining('このまま押し続けると'), findsNothing);
    expect(await exists('e1'), isTrue);
  });

  testWidgets('5秒押し続けると削除する', (t) async {
    await open(t, '編集 花子');
    // 文字の外側（ボタンの余白）を押しても反応する。
    final button = find.byKey(const ValueKey('削除')).hitTestable();
    final g = await t
        .startGesture(t.getRect(button).bottomCenter - const Offset(0, 4));
    await t.pump();
    await t.pump(const Duration(milliseconds: 4900));
    expect(await exists('e1'), isTrue);
    await t.pump(const Duration(milliseconds: 200));
    await g.up();
    await t.pumpAndSettle();
    expect((await db.collection('users').doc('e1').get()).exists, isFalse);
    expect((await db.collection('roles').doc('e1').get()).exists, isFalse);
    expect(label('編集 花子'), findsNothing);
    expect(label('スタッフ情報を削除しました'), findsOneWidget);
  });
}
