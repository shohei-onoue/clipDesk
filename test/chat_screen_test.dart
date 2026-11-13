import 'dart:io';
import 'dart:ui' as ui;

import 'package:clipdesk/data/request_repository.dart';
import 'package:clipdesk/data/services.dart';
import 'package:clipdesk/domain/brief.dart';
import 'package:clipdesk/screens/chat_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    Services.repo = RequestRepository(db: FakeFirebaseFirestore());
  });

  test('投稿先・視聴者などを保存して復元し、旧指示書も読み込める', () {
    const brief =
        Brief(videoType: '会社紹介', platform: 'YouTube', audience: '採用候補者');
    final restored = Brief.fromMap('採用動画', brief.toMap());
    expect(restored.videoType, '会社紹介');
    expect(restored.platform, 'YouTube');
    expect(restored.copyWith(purpose: '採用').audience, '採用候補者');
    expect(Brief.fromMap('旧依頼', {}).platform, isEmpty);
  });

  testWidgets('入力と選択で質問が進み、空回答は送信できない', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final font = FontLoader('NotoSansJP')
        ..addFont(rootBundle.load('assets/fonts/NotoSansJP-Variable.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    final boundary = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        home: RepaintBoundary(key: boundary, child: const ChatScreen())));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/navigater.png'),
        tester.element(find.byType(ChatScreen))));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == '回答を送信'))
            .onPressed,
        isNull);
    await tester.tap(find.byTooltip('ファイルを添付'));
    await tester.pumpAndSettle();
    expect(find.text('編集する動画'), findsOneWidget);
    expect(find.text('参考画像・写真'), findsOneWidget);
    expect(find.text('参考動画・ファイル'), findsOneWidget);
    Navigator.of(tester.element(find.text('編集する動画'))).pop();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '秋の会社紹介');
    await tester.pump();
    await tester.tap(find.byTooltip('回答を送信'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('会社紹介'));
    await tester.pumpAndSettle();
    expect(find.text('どこに投稿しますか？'), findsOneWidget);
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('/tmp/clipdesk-chat-preview.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.text('Instagram'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('認知を広げたい'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30秒'));
    await tester.pumpAndSettle();
    // 決定済みの「30秒」をタップすると、メニューで選び直せる（チャットは増えない）。
    final before = find.byType(Text).evaluate().length;
    // 最新の質問が画面トップに来るため、過去の回答は上へスクロールして出す。
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30秒'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('60秒'));
    await tester.pumpAndSettle();
    expect(find.text('30秒'), findsNothing);
    expect(find.text('60秒'), findsOneWidget);
    expect(find.byType(Text).evaluate().length, before);
    expect(find.text('縦型'), findsOneWidget);
    await tester.tap(find.text('縦型'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('あり'));
    await tester.pumpAndSettle();
    // 希望納期は、添付の前に聞く。
    expect(find.text('希望納期を選んでください。'), findsOneWidget);
    expect(find.text('納期を選ぶ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
