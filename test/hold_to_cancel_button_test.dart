import 'package:clipdesk/widgets/hold_to_cancel_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<int Function()> pump(WidgetTester t, {double width = 300}) async {
    var done = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: HoldToCancelButton(onConfirmed: () => done++),
          ),
        ),
      ),
    ));
    return () => done;
  }

  testWidgets('5秒間押し続けると取り消しが実行される', (t) async {
    final done = await pump(t);
    final g = await t.startGesture(t.getCenter(find.text('依頼取消')));
    await t.pump(); // 最初のフレームで時計が動き出す
    await t.pump(const Duration(seconds: 4));
    expect(done(), 0);
    // 押している間は、画面の中心にドーナツグラフのポップアップが出る（残り秒数つき）。
    expect(find.textContaining('このまま押し続けると'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 1100));
    expect(done(), 1);
    expect(find.textContaining('このまま押し続けると'), findsNothing);
    await g.up();
    await t.pumpAndSettle();
    expect(done(), 1);
  });

  testWidgets('途中で離すと取り消さない。短く押すと案内が出る', (t) async {
    final done = await pump(t);
    final g = await t.startGesture(t.getCenter(find.text('依頼取消')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('このまま押し続けると'), findsOneWidget);
    await g.up();
    await t.pump(const Duration(seconds: 6));
    expect(done(), 0);
    expect(find.textContaining('このまま押し続けると'), findsNothing);
    expect(find.textContaining('長押しすると依頼を取り消します'), findsOneWidget);
  });

  testWidgets('幅が狭くても表示できる（2:2:1 の1）', (t) async {
    await pump(t, width: 70);
    expect(find.text('依頼取消'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
