import 'package:clipdesk/core/app_settings.dart';
import 'package:clipdesk/core/boot.dart';
import 'package:clipdesk/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ログイン入力欄は文字サイズを大に設定しても標準で表示する', (tester) async {
    final settings = AppSettings.instance;
    final previousBootState = Boot.state.value;
    addTearDown(() {
      Boot.state.value = previousBootState;
      settings.resetForTest();
    });
    await tester.runAsync(() => settings.setTextSize(TextSizeLevel.large));
    Boot.state.value = BootState.ready;

    await tester.pumpWidget(const ClipDeskApp());
    await tester.pump();

    final fields = find.byType(EditableText);
    expect(fields, findsNWidgets(2));
    for (final field in tester.elementList(fields)) {
      expect(MediaQuery.textScalerOf(field).scale(16), 16);
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
