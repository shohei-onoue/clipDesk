import 'package:clipdesk/widgets/swipe_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('左へのスライドでボタンが出て、右へのスライドで閉じる', (tester) async {
    var taps = 0;
    var deleted = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListView(children: [
      SwipeActions(
        actions: [
          SwipeAction(
              icon: Icons.delete_outline,
              label: '削除',
              color: Colors.red,
              onTap: () => deleted++),
        ],
        child: GestureDetector(
          onTap: () => taps++,
          child: const SizedBox(
              key: Key('card'),
              width: double.infinity,
              height: 100,
              child: ColoredBox(color: Colors.grey)),
        ),
      ),
    ]))));
    final card = find.byKey(const Key('card'));
    final start = tester.getTopLeft(card).dx;

    await tester.drag(card, const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(card).dx, lessThan(start - 50));

    // 開いたカードの上を右へスライドすると、閉じる。
    await tester.dragFrom(const Offset(100, 50), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(card).dx, start);
    expect((taps, deleted), (0, 0));

    // 開いているときのタップは、閉じるだけ。閉じたあとのタップは、カードの操作。
    await tester.drag(card, const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(100, 50));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(card).dx, start);
    expect(taps, 0);
    await tester.tapAt(const Offset(100, 50));
    await tester.pumpAndSettle();
    expect(taps, 1);

    // ボタンは押せる。
    await tester.drag(card, const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });
}
