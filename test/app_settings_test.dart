import 'package:clipdesk/core/app_colors.dart';
import 'package:clipdesk/core/app_settings.dart';
import 'package:clipdesk/core/ruby_dictionary.dart';
import 'package:clipdesk/widgets/detail_widgets.dart';
import 'package:clipdesk/widgets/ruby_text.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final settings = AppSettings.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settings.resetForTest();
  });
  tearDown(settings.resetForTest);

  test('標準の設定は従来の見た目：小・デフォルトの配色・ふりがなオフ', () {
    expect(settings.textSize, TextSizeLevel.small);
    expect(settings.textSize.scale, 1.0);
    expect(settings.palette, AppPalette.standard);
    expect(settings.ruby, isFalse);
    expect(AppColors.ink, const Color(0xFF1A1D20));
    expect(AppColors.white, const Color(0xFFF5F5F5));
    expect(AppColors.amber, const Color(0xFFD97706));
    expect(AppColors.blue, const Color(0xFF0052CC));
    // 面のグレーは、従来の「白 8%」と同じ。
    expect(AppColors.gray, AppColors.white.withValues(alpha: 0.08));
  });

  test('文字の大きさは、小・中・大が 1・1.5・2 倍', () {
    expect([for (final l in TextSizeLevel.values) l.scale], [1.0, 1.5, 2.0]);
  });

  test('色の組み合わせは5つで、選ぶと AppColors が変わる', () async {
    expect(AppPalette.values.length, 5);
    await settings.setPalette(AppPalette.ocean);
    expect(AppColors.ink, AppPalette.ocean.ink);
    expect(AppColors.blue, AppPalette.ocean.blue);
    expect(AppColors.badgeRed, const Color(0xFFD32F2F)); // 固定
  });

  test('設定を保存して、読み込める', () async {
    await settings.setTextSize(TextSizeLevel.large);
    await settings.setPalette(AppPalette.light);
    await settings.setRuby(true);
    settings.resetForTest();
    expect(settings.textSize, TextSizeLevel.small);
    await settings.load();
    expect(settings.textSize, TextSizeLevel.large);
    expect(settings.palette, AppPalette.light);
    expect(settings.ruby, isTrue);
  });

  test('変更したら、購読者へ知らせる', () async {
    var n = 0;
    settings.addListener(() => n++);
    await settings.setRuby(true);
    await settings.setRuby(true); // 同じ値は知らせない
    await settings.setTextSize(TextSizeLevel.medium);
    expect(n, 2);
  });

  test('各配色の文字と背景のコントラスト比は 4.5 以上', () {
    double lum(Color c) => c.computeLuminance();
    double ratio(Color a, Color b) {
      final x = lum(a), y = lum(b);
      return ((x > y ? x : y) + 0.05) / ((x > y ? y : x) + 0.05);
    }

    for (final p in AppPalette.values) {
      expect(ratio(p.white, p.ink), greaterThanOrEqualTo(4.5), reason: p.label);
      expect(ratio(p.on(p.blue), p.blue), greaterThanOrEqualTo(4.0),
          reason: p.label);
      expect(ratio(p.on(p.amber), p.amber), greaterThanOrEqualTo(4.5),
          reason: p.label);
    }
  });

  group('ふりがな', () {
    test('辞書の語に、読みを付ける（送りがなはそのまま）', () {
      final segs = RubyDictionary.segment('依頼する');
      expect(segs.map((s) => (s.base, s.ruby)).toList(),
          [('依頼', 'いらい'), ('する', null)]);
      final okuri = RubyDictionary.segment('選んでください');
      expect(okuri.first.base, '選');
      expect(okuri.first.ruby, 'えら');
      expect(okuri.map((s) => s.base).join(), '選んでください');
    });

    test('長い語を優先する。辞書にない漢字は、そのまま', () {
      final segs = RubyDictionary.segment('承認待ち');
      expect(segs.first.base, '承認待');
      expect(segs.first.ruby, 'しょうにんま');
      final unknown = RubyDictionary.segment('撮影');
      expect(unknown.single.ruby, isNull);
    });

    test('「小」「中」「大」は、文字列全体が一致するときだけ読みを付ける', () {
      expect(RubyDictionary.segment('小').single.ruby, 'しょう');
      expect(
          RubyDictionary.segment('小さい').every((s) => s.ruby == null), isTrue);
    });

    testWidgets('オンのときだけ、ふりがなを表示する', (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('依頼を確認します'))));
      expect(find.text('いらい'), findsNothing);
      await settings.setRuby(true);
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('依頼を確認します'))));
      expect(find.text('いらい'), findsOneWidget);
      expect(find.text('かくにん'), findsOneWidget);
      expect(find.bySemanticsLabel('依頼を確認します'), findsOneWidget);
    });
  });

  testWidgets('ふりがな付きの漢字は、まわりの文字と下の端がそろう', (tester) async {
    await AppSettings.instance.setRuby(true);
    addTearDown(() => AppSettings.instance.setRuby(false));
    await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
            child: Text('デモ編集者', style: TextStyle(fontSize: 24, height: 1)))));
    final outer = find.byType(RichText).first;
    final paragraph = tester.renderObject<RenderParagraph>(outer);
    final plain = paragraph
        .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 2))
        .last;
    final plainBottom = tester.getTopLeft(outer).dy + plain.bottom;
    expect(tester.getBottomLeft(find.text('編集者')).dy,
        moreOrLessEquals(plainBottom, epsilon: 0.5));
  });

  for (final (name, level, ruby) in [
    ('小・ふりがななし', TextSizeLevel.small, false),
    ('大・ふりがなあり', TextSizeLevel.large, true),
  ]) {
    testWidgets('お知らせの拡声器は、1行目の本文の字と下の端がそろう（$name）', (tester) async {
      // 字の位置を測るので、実際のフォントを読み込む。
      await tester.runAsync(() async {
        for (final (family, asset) in [
          ('NotoSansJP', 'assets/fonts/NotoSansJP-Variable.ttf'),
          ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
        ]) {
          await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
        }
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await settings.setTextSize(level);
      await settings.setRuby(ruby);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(level.scale)),
              child: child!),
          home: const Scaffold(
              body: Align(
                  alignment: Alignment.topLeft,
                  child: NoticeBar('編集者の受注待ちです。')))));
      // いちばん外側の文字の段落（ふりがなは、この中に埋め込まれる）。
      final outer = find
          .descendant(
              of: find.byType(NoticeBar),
              matching: find.byWidgetPredicate((w) =>
                  w is RichText && w.text.style?.fontFamily != 'MaterialIcons'))
          .first;
      final paragraph = tester.renderObject<RenderParagraph>(outer);
      final baseline = tester.getTopLeft(outer).dy +
          paragraph.getDryBaseline(
              paragraph.constraints, TextBaseline.alphabetic)!;
      final icon = find.byIcon(Icons.campaign_outlined);
      // アイコンの字の下端（絵の下の余白を除く）は、本文の字の下端（基準線より少し下）。
      final iconInk = tester.getBottomLeft(icon).dy - 24 * 0.166;
      expect(iconInk,
          moreOrLessEquals(baseline + 14 * level.scale * 0.07, epsilon: 0.5));
      // 本文の位置は、アイコンに押し下げられない。
      expect(tester.getTopLeft(outer).dy, moreOrLessEquals(4, epsilon: 0.5));
    });
  }
}
