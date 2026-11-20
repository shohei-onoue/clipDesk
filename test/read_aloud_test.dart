import 'package:clipdesk/core/app_settings.dart';
import 'package:clipdesk/widgets/ruby_text.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final spoken = <String>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    spoken.clear();
    AppSettings.instance.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'),
            (c) async {
      if (c.method == 'speak') spoken.add(c.arguments as String);
      return 1;
    });
  });

  Widget app() =>
      const MaterialApp(home: Scaffold(body: Center(child: Text('音声で読み上げる'))));

  testWidgets('読み上げオン：0.2秒を超える長押しで読み上げる', (tester) async {
    await AppSettings.instance.setReadAloud(true);
    await tester.pumpWidget(app());
    final g =
        await tester.startGesture(tester.getCenter(find.text('音声で読み上げる')));
    await tester.pump(const Duration(milliseconds: 150));
    expect(spoken, isEmpty);
    await tester.pump(const Duration(milliseconds: 200));
    await g.up();
    expect(spoken, ['音声で読み上げる']);
  });

  testWidgets('読み上げオン：タップだけでは読み上げない', (tester) async {
    await AppSettings.instance.setReadAloud(true);
    await tester.pumpWidget(app());
    await tester.tap(find.text('音声で読み上げる'));
    await tester.pump(const Duration(seconds: 3));
    expect(spoken, isEmpty);
  });

  testWidgets('読み上げオフ：長押ししても読み上げない', (tester) async {
    await tester.pumpWidget(app());
    final g =
        await tester.startGesture(tester.getCenter(find.text('音声で読み上げる')));
    await tester.pump(const Duration(seconds: 3));
    await g.up();
    expect(spoken, isEmpty);
  });

  testWidgets('テキストボタン：タップで操作、0.2秒超の長押しで読み上げ', (tester) async {
    await AppSettings.instance.setReadAloud(true);
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: TextButton(
                    onPressed: () => taps++, child: const Text('履歴を見る'))))));
    await tester.tap(find.text('履歴を見る'));
    await tester.pump(const Duration(seconds: 3));
    expect(taps, 1);
    // 0.15秒のタップも、ボタンとして働く。
    final t = await tester.startGesture(tester.getCenter(find.text('履歴を見る')));
    await tester.pump(const Duration(milliseconds: 150));
    await t.up();
    await tester.pump(const Duration(seconds: 2));
    expect(taps, 2);
    expect(spoken, isEmpty);
    final g = await tester.startGesture(tester.getCenter(find.text('履歴を見る')));
    await tester.pump(const Duration(milliseconds: 350));
    await g.up();
    expect(spoken, ['履歴を見る']);
    // 長押しで読み上げたときは、ボタンの操作は働かない。
    expect(taps, 2);
  });
}
