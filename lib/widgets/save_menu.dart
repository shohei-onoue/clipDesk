import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../data/services.dart';
import '../data/storage_service.dart';
import 'ruby_text.dart';

enum _Dest {
  local('この端末に保存', null, null),
  dropbox('Dropbox', 'https://www.dropbox.com/home', 'Dropbox'),
  drive(
      'Google ドライブ', 'https://drive.google.com/drive/my-drive', 'Google ドライブ'),
  onedrive('OneDrive', 'https://onedrive.live.com/', 'OneDrive');

  const _Dest(this.label, this.url, this.service);
  final String label;
  final String? url;
  final String? service;
}

/// ダウンロードボタンをタップして、保存先のメニューを出す（添付資料・ライブラリの動画）。
/// 「この端末に保存」か、Dropbox／Google ドライブ／OneDrive から選ぶ。
/// クラウドを選ぶと、そのサービスの画面を開き、続けてファイルを端末に保存する。
/// クラウドサービスへのログインは、開いたサービスの画面で利用者自身が行う
/// （アプリはIDやパスワードを扱わない）。
/// [context] は、ボタンの位置を取るため、ボタン自身のものを渡す。
Future<void> showSaveMenu(BuildContext context,
    {required String path, required String name}) async {
  final box = context.findRenderObject() as RenderBox;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    ),
    Offset.zero & overlay.size,
  );
  final dest = await showMenu<_Dest>(
    context: context,
    position: position,
    color: AppColors.ink,
    shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.white.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(10)),
    items: [
      for (final d in _Dest.values)
        PopupMenuItem<_Dest>(
          value: d,
          child: Row(children: [
            Icon(
                d == _Dest.local ? Icons.download : Icons.cloud_upload_outlined,
                size: 20,
                color: AppColors.white),
            const SizedBox(width: 10),
            Text(d.label, style: AppText.dark(14, weight: FontWeight.w400)),
          ]),
        ),
    ],
  );
  if (dest == null || !context.mounted) return;
  if (dest == _Dest.local) {
    await _saveLocal(context, path, name);
    return;
  }
  // 選んだサービスを、すぐ開く（時間をおくと、ブラウザが新しいタブをふさぐことがある）。
  // ログインは、開いた画面で利用者自身が行う。そのあと、ファイルを端末に保存する。
  final opened = await launchUrl(Uri.parse(dest.url!));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(opened
          ? '${dest.service}を開きました。ログインして、これから保存するファイルをアップロードしてください'
          : '${dest.service}を開けませんでした。ファイルを保存して、ご自身で開いてください')));
  await _saveLocal(context, path, name);
}

/// ボタンをひと押しで、端末に保存する（保存先は端末の保存ダイアログで選ぶ）。
Future<bool> saveToDevice(BuildContext context,
        {required String path, required String name}) =>
    _saveLocal(context, path, name);

Future<bool> _saveLocal(BuildContext context, String path, String name) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(SnackBar(content: Text('「$name」を読み込んでいます…')));
  try {
    final bytes = await Services.repo.readBytes(path);
    final ext = name.split('.').last.toLowerCase();
    final saved = await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      dialogTitle: '保存先を選んでください',
      mimeType: StorageService.contentTypeFor(name,
          video: const {'mp4', 'mov', 'm4v', 'webm'}.contains(ext)),
    );
    messenger.hideCurrentSnackBar();
    if (saved == null) return false; // 利用者が取りやめた
    messenger.showSnackBar(SnackBar(content: Text('「$name」を保存しました')));
    return true;
  } catch (e) {
    // 読み込み・保存の画面が使えないときは、ブラウザで開く。
    try {
      final url = await Services.repo.downloadUrl(path);
      await launchUrl(Uri.parse(url));
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(
          content:
              Text('ファイルを直接保存できなかったため、ブラウザで開きました。保存するには、保存用の設定（CORS）が必要です')));
      return true;
    } catch (e2) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('保存できませんでした：$e2')));
      return false;
    }
  }
}
