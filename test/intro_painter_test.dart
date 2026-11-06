import 'package:clipdesk/widgets/intro_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opening paints each transition and the login form background', (
    tester,
  ) async {
    final time = ValueNotifier<double>(0);
    final hide = ValueNotifier<double>(0);
    await tester.pumpWidget(
      MaterialApp(
        home: CustomPaint(painter: IntroPainter(time, hide)),
      ),
    );
    for (final seconds in <double>[
      0, 1, 3.9, 4, 5.7, 6.7, 7.45, 11, 13, 15, 17.2, 18.2, 19.7,
    ]) {
      time.value = seconds;
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'at $seconds seconds');
    }
    hide.value = 1;
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    time.dispose();
    hide.dispose();
  });
}
