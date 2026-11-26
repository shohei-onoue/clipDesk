import 'dart:io';
import 'dart:ui' as ui;

import 'package:clipdesk/core/app_settings.dart';
import 'package:clipdesk/data/request_repository.dart';
import 'package:clipdesk/data/services.dart';
import 'package:clipdesk/data/storage_service.dart';
import 'package:clipdesk/domain/brief.dart';
import 'package:clipdesk/screens/chat_screen.dart';
import 'package:clipdesk/widgets/app_drawer.dart';
import 'package:clipdesk/screens/delivery_library_screen.dart';
import 'package:clipdesk/screens/menu_screen.dart';
import 'package:clipdesk/screens/notifications_screen.dart';
import 'package:clipdesk/screens/request_detail_screen.dart';
import 'package:clipdesk/screens/requester_home_screen.dart';
import 'package:clipdesk/screens/settings_screen.dart';
import 'package:clipdesk/screens/staff_admin_screen.dart';
import 'package:clipdesk/screens/staff_invite_screen.dart';
import 'package:clipdesk/widgets/chat_widgets.dart';
import 'package:clipdesk/widgets/ruby_text.dart' as ruby;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 文字の大きさ（中・大）・ふりがな・色の組み合わせを変えたときに、
/// 画面の部品がはみ出さない（RenderFlex overflow が出ない）ことを確かめる。
class _FakeStorage extends StorageService {
  @override
  Future<void> upload(String path, UploadFile file,
      {required String contentType}) async {}
}

UploadFile _file(String n) =>
    UploadFile(name: n, size: 3, read: () async => Uint8List(3));

void main() {
  late FakeFirebaseFirestore db;
  final settings = AppSettings.instance;

  setUp(() async {
    db = FakeFirebaseFirestore();
    final repo = RequestRepository(db: db, storage: _FakeStorage());
    Services.repo = repo;
    Services.uidOverride = 'u1';
    await db
        .collection('roles')
        .doc('u1')
        .set({'role': 'staff', 'manager': true});
    await db
        .collection('roles')
        .doc('e1')
        .set({'role': 'staff', 'manager': false});
    await db.collection('users').doc('u1').set({
      'name': '依頼 太郎',
      'lastName': '依頼',
      'firstName': '太郎',
      'email': 'u1@example.com'
    });
    await db.collection('users').doc('e1').set({
      'name': '編集 花子',
      'lastName': '編集',
      'firstName': '花子',
      'email': 'e1@example.com'
    });
    const brief = Brief(
        title: '新商品紹介動画の制作をお願いします',
        videoType: '会社紹介',
        platform: 'YouTube、Instagram',
        purpose: '認知拡大のため',
        audience: '採用候補者',
        structure: '紹介→購入案内',
        deliveryTerms: '30秒・縦型・字幕あり',
        scenes: [Scene(title: '冒頭', instruction: '商品を大写し')]);
    for (final id in ['r1', 'r2', 'r3']) {
      await repo.createRequest(
          requestId: id,
          requesterId: 'u1',
          brief: brief,
          dueDate: DateTime.now().add(const Duration(days: 20)),
          videos: [_file('a.mp4')],
          references: [_file('ref.pdf')]);
    }
    await repo.startEditing(requestId: 'r2', uid: 'e1');
    await repo.startEditing(requestId: 'r3', uid: 'e1');
    await repo.askForInfo(
        requestId: 'r3', uid: 'e1', reason: 'BGMの雰囲気を教えてください');
    // 登録待ちの招待（スタッフ管理の「再送」「取消」）。
    await repo.saveInvite('new.staff@example.com',
        manager: false, invitedBy: 'u1');
    settings.resetForTest();
  });

  tearDown(() {
    Services.uidOverride = null;
    settings.resetForTest();
  });

  // 画面ごとに、データが読み込まれて表示されたことの目印（読み込み中のままだと、はみ出しを見逃すため）。
  final marks = <String, String>{
    'ダッシュボード': '新商品紹介',
    'ライブラリ': '',
    '依頼詳細（編集中）': '新商品紹介',
    'スタッフ管理': '編集 花子',
  };

  final screens = <String, Widget Function()>{
    'メイン': () => const MenuScreen(),
    'ダッシュボード': () => const RequesterHomeScreen(),
    'ライブラリ': () => const DeliveryLibraryScreen(),
    '通知': () => const NotificationsScreen(),
    '依頼詳細（受付待ち）': () => const RequestDetailScreen(requestId: 'r1'),
    '依頼詳細（編集中）': () => const RequestDetailScreen(requestId: 'r2'),
    '依頼詳細（問合せ中）': () => const RequestDetailScreen(requestId: 'r3'),
    'スタッフ管理': () => const StaffAdminScreen(),
    'スタッフ招待': () => const StaffInviteScreen(),
    '設定': () => const SettingsScreen(),
    '指示チャット': () => const ChatScreen(),
    'ドロワー': () => const _DrawerOpened(),
    // 開いてから確かめるダイアログ・シート（操作は openers）。
    '通知ダイアログ': () => const MenuScreen(),
    'スタッフ編集ダイアログ': () => const StaffAdminScreen(),
    '添付のシート': () => const ChatScreen(),
    '動画の長さのシート': () => const ChatScreen(),
  };

  final openers = <String, Future<void> Function(WidgetTester)>{
    '通知ダイアログ': (tester) => _tap(tester, find.byTooltip('通知')),
    'スタッフ編集ダイアログ': (tester) async {
      await tester.drag(_label('編集 花子').first, const Offset(-300, 0));
      await _settle(tester);
      await _tap(tester, _label('編集').last);
      expect(find.byType(AlertDialog), findsOneWidget);
    },
    '添付のシート': (tester) async {
      await _answerUntil(
          tester, () => find.byTooltip('ファイルを添付').evaluate().isNotEmpty);
      await _tap(tester, find.byTooltip('ファイルを添付'));
      expect(find.byType(BottomSheet), findsOneWidget);
    },
    '動画の長さのシート': (tester) async {
      await _answerUntil(
          tester, () => find.byType(CupertinoPicker).evaluate().isNotEmpty,
          customLength: true);
      // 1項目の高さに、数字の行が収まる（前後の項目と重ならない）。
      final picker =
          tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
      expect(tester.getSize(_label('45秒')).height,
          lessThanOrEqualTo(picker.itemExtent));
    },
  };

  final cases = <String, void Function()>{
    '標準': () {},
    '中': () => settings.setTextSize(TextSizeLevel.medium),
    '大': () => settings.setTextSize(TextSizeLevel.large),
    '小＋ふりがな': () => settings.setRuby(true),
    '大＋ふりがな': () {
      settings.setTextSize(TextSizeLevel.large);
      settings.setRuby(true);
    },
  };

  // 色の組み合わせは、色だけの違いなので、代表の画面だけで見た目を確かめる。
  const paletteScreens = ['メイン', 'ダッシュボード', '設定', '依頼詳細（編集中）'];
  for (final p in AppPalette.values.skip(1)) {
    cases['配色：${p.label}'] = () => settings.setPalette(p);
  }

  for (final c in cases.entries) {
    for (final s in screens.entries) {
      if (c.key.startsWith('配色') && !paletteScreens.contains(s.key)) continue;
      testWidgets('${s.key}：${c.key}', (tester) async {
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
        c.value();
        final errors = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) {
          final t = d.exceptionAsString();
          if (t.contains('overflowed')) {
            errors.add(t.split('\n').first);
          } else {
            errors.add(
                'その他：${t.split('\n').first}\n${d.stack.toString().split('\n').take(6).join('\n')}');
          }
        };
        try {
          await tester.pumpWidget(MaterialApp(
            locale: const Locale('ja'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(settings.textSize.scale)),
              child: child!,
            ),
            home: s.value(),
          ));
          for (var i = 0; i < 3; i++) {
            await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 80)));
            await tester.pump(const Duration(seconds: 1));
          }
          await openers[s.key]?.call(tester);
          await _settle(tester);
          // 画面の画像を保存する（SHOT_DIR を指定したときだけ。見た目の確認用）。
          final dir = Platform.environment['SHOT_DIR'];
          if (dir != null) {
            await tester.runAsync(() async {
              final b = tester.renderObject<RenderRepaintBoundary>(find
                  .descendant(
                      of: find.byType(MaterialApp),
                      matching: find.byType(RepaintBoundary))
                  .first);
              final img = await b.toImage(pixelRatio: 1);
              final bytes =
                  await img.toByteData(format: ui.ImageByteFormat.png);
              File('$dir/${s.key}_${c.key}.png')
                  .writeAsBytesSync(bytes!.buffer.asUint8List());
            });
          }
        } finally {
          FlutterError.onError = old;
        }
        final mark = marks[s.key];
        if (mark != null && mark.isNotEmpty && !settings.ruby) {
          final texts = tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
              .join(' | ');
          expect(texts, contains(mark), reason: '${s.key}のデータが表示されていません');
        }
        errors.removeWhere((e) => e.contains('ink splashes'));
        expect(errors, isEmpty);
      });
    }
  }
}

/// ふりがなの有無にかかわらず、その文字の部品を探す。
Finder _label(String text) =>
    find.byWidgetPredicate((w) => w is ruby.Text && w.data == text,
        description: text);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 2; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  expect(target, findsWidgets);
  await tester.ensureVisible(target.first);
  await tester.pump(const Duration(milliseconds: 600));
  await tester.tap(target.first);
  await _settle(tester);
}

/// 指示チャットの質問に順に答えて、[done] になるまで進める。
/// [customLength] なら、長さの質問で「直接入力」を選ぶ（秒数のシートが出る）。
Future<void> _answerUntil(WidgetTester tester, bool Function() done,
    {bool customLength = false}) async {
  final chips = find.byType(AppChip);
  for (var i = 0; i < 30 && !done(); i++) {
    if (chips.evaluate().isNotEmpty) {
      var target = chips.first;
      for (final text in ['直接入力', '指示はなし', 'いいえ']) {
        // 「直接入力」は、長さの質問（30秒がある）のときだけ選ぶ。
        if (text == '直接入力' &&
            (!customLength || _label('30秒').evaluate().isEmpty)) {
          continue;
        }
        final found = find.descendant(of: chips, matching: _label(text));
        if (found.evaluate().isNotEmpty) {
          target = found.first;
          break;
        }
      }
      await _tap(tester, target);
      if (find.byType(DatePickerDialog).evaluate().isNotEmpty) {
        await _tap(tester, find.text('OK'));
      }
    } else {
      await tester.enterText(find.byType(TextField).last, 'テストの回答');
      await tester.pump();
      await _tap(tester, find.byTooltip('回答を送信'));
    }
  }
  expect(done(), isTrue, reason: '指示チャットを目的の質問まで進められませんでした');
}

/// ドロワーを開いた状態の画面。
class _DrawerOpened extends StatefulWidget {
  const _DrawerOpened();

  @override
  State<_DrawerOpened> createState() => _DrawerOpenedState();
}

class _DrawerOpenedState extends State<_DrawerOpened> {
  final _key = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _key.currentState?.openDrawer());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        key: _key,
        drawer: const AppDrawer(),
        body: const SizedBox.expand(),
      );
}
