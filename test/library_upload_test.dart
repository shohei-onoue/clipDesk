import 'dart:typed_data';

import 'package:clipdesk/core/app_settings.dart';
import 'package:clipdesk/data/request_repository.dart';
import 'package:clipdesk/data/services.dart';
import 'package:clipdesk/data/storage_service.dart';
import 'package:clipdesk/screens/delivery_library_screen.dart';
import 'package:clipdesk/widgets/library_upload_dialog.dart';
import 'package:clipdesk/widgets/ruby_text.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_test/flutter_test.dart';

class _FakeStorage extends StorageService {
  @override
  Future<void> upload(String path, UploadFile file,
      {required String contentType}) async {}

  @override
  Future<String> downloadUrl(String path) async => 'https://example.com/$path';
}

void main() {
  testWidgets('ライブラリの「＋」から動画を追加すると、カードに題名・日時・投稿者名が出る', (tester) async {
    AppSettings.instance.resetForTest();
    final db = FakeFirebaseFirestore();
    Services.repo = RequestRepository(db: db, storage: _FakeStorage());
    Services.uidOverride = 'u1';
    final original = pickLibraryVideo;
    addTearDown(() {
      pickLibraryVideo = original;
      Services.uidOverride = null;
    });
    pickLibraryVideo = () async => UploadFile(
        name: 'finished.mp4', size: 3, read: () async => Uint8List(3));
    await db.collection('roles').doc('u1').set({'role': 'staff'});
    await db.collection('users').doc('u1').set({'name': '山田 花子'});

    Future<void> settle() async {
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(seconds: 1));
      }
    }

    await tester.pumpWidget(const MaterialApp(home: DeliveryLibraryScreen()));
    await settle();
    await tester.tap(find.byTooltip('完成した動画を追加'));
    await settle();
    // 投稿者名には、自分の名前が入る。
    expect(find.widgetWithText(TextField, '山田 花子'), findsOneWidget);

    await tester.tap(find.text('動画を選ぶ'));
    await settle();
    expect(find.text('finished.mp4'), findsOneWidget);
    // タイトルが空なら、追加しない。
    await tester.tap(find.text('アップロード'));
    await settle();
    expect(find.text('エラー：動画タイトルが未入力です。入力してください'), findsOneWidget);
    expect((await db.collection('requests').get()).docs, isEmpty);

    await tester.enterText(find.byType(TextField).first, '会社紹介の完成版');
    await tester.tap(find.text('アップロード'));
    await settle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('ライブラリに追加しました'), findsOneWidget);
    expect(find.text('会社紹介の完成版'), findsOneWidget);
    expect(find.text('山田 花子'), findsOneWidget);
    final saved = (await db.collection('requests').get()).docs.single.data();
    final at = (saved['approvedAt'] as dynamic).toDate() as DateTime;
    String two(int n) => n.toString().padLeft(2, '0');
    expect(
        find.text(
            '${at.year}/${two(at.month)}/${two(at.day)} ${two(at.hour)}:${two(at.minute)}'),
        findsOneWidget);
    expect(DateTime.now().difference(at).inMinutes, lessThan(1));
  });
}
