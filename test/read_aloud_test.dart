import 'package:clipdesk/core/app_settings.dart';
import 'package:clipdesk/widgets/detail_widgets.dart';
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

  testWidgets('下線の文字ボタン：位置の無いタップ（Web の短いタップ）でも操作できる', (tester) async {
    final semantics = tester.ensureSemantics();
    for (final readAloud in [false, true]) {
      await AppSettings.instance.setReadAloud(readAloud);
      final taps = <Offset>[];
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Center(
                  child: TapEditText('履歴を見る',
                      key: ValueKey(readAloud),
                      label: '問合せ履歴',
                      style: const TextStyle(),
                      onTap: taps.add)))));
      final center = tester.getCenter(find.byType(TapEditText));
      tester.semantics.tap(find.semantics.byLabel(RegExp('問合せ履歴を編集')));
      await tester.pump(const Duration(seconds: 1));
      expect(taps, [center], reason: '読み上げ：$readAloud');
      // 指のタップは、押した位置が渡り、操作は1回だけ。
      await tester.tapAt(center + const Offset(8, 0));
      await tester.pump(const Duration(seconds: 1));
      expect(taps, [center, center + const Offset(8, 0)],
          reason: '読み上げ：$readAloud');
    }
    expect(spoken, isEmpty);
    semantics.dispose();
  });

  testWidgets('合図が遅れて届いても、触れてから0.2秒で読み上げに切り替わる', (tester) async {
    await AppSettings.instance.setReadAloud(true);
    final original = readAloudEventAge;
    addTearDown(() => readAloudEventAge = original);
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: TextButton(
                    onPressed: () => taps++, child: const Text('履歴を見る'))))));
    // 触れてから 0.15 秒たって届いた：残りの 0.05 秒で切り替わる。
    readAloudEventAge = (_) => const Duration(milliseconds: 150);
    var g = await tester.startGesture(tester.getCenter(find.text('履歴を見る')));
    await tester.pump(const Duration(milliseconds: 40));
    expect(spoken, isEmpty);
    await tester.pump(const Duration(milliseconds: 20));
    await g.up();
    await tester.pump(const Duration(seconds: 1));
    expect(spoken, ['履歴を見る']);
    expect(taps, 0);
    // 0.2 秒以上たって届いた：すぐ切り替わる。
    spoken.clear();
    readAloudEventAge = (_) => const Duration(milliseconds: 230);
    g = await tester.startGesture(tester.getCenter(find.text('履歴を見る')));
    await tester.pump(const Duration(milliseconds: 1));
    await g.up();
    await tester.pump(const Duration(seconds: 1));
    expect(spoken, ['履歴を見る']);
    expect(taps, 0);
  });
}
