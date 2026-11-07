import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// 1ファイルの上限。容量制限はFigJamで未確定のため暫定値（storage.rulesと揃える）。
const int kMaxFileBytes = 500 * 1024 * 1024;

/// 選択したファイル（名前・サイズ・読み出し）。ピッカーの実装に依存させない。
class UploadFile {
  UploadFile({required this.name, required this.size, required this.read});

  final String name;
  final int size;
  final Future<Uint8List> Function() read;

  static Future<UploadFile> fromPicked(PlatformFile f) async => UploadFile(
        name: f.name,
        size: await f.length() ?? f.lengthSync() ?? 0,
        read: f.readAsBytes,
      );
}

class StorageService {
  StorageService([this._injected]);

  final FirebaseStorage? _injected;
  FirebaseStorage get _storage => _injected ?? FirebaseStorage.instance;

  /// 選択したファイルを [path] に保存する。失敗時は例外を投げる。
  Future<void> upload(String path, UploadFile file,
      {required String contentType}) async {
    if (file.size > kMaxFileBytes) {
      throw StateError('ファイルが大きすぎます（上限 ${kMaxFileBytes ~/ 1024 ~/ 1024}MB）');
    }
    await _storage
        .ref(path)
        .putData(await file.read(), SettableMetadata(contentType: contentType));
  }

  Future<String> downloadUrl(String path) =>
      _storage.ref(path).getDownloadURL();

  static String contentTypeFor(String name, {required bool video}) {
    final ext = name.split('.').last.toLowerCase();
    if (video) {
      return switch (ext) {
        'mov' => 'video/quicktime',
        'webm' => 'video/webm',
        _ => 'video/mp4',
      };
    }
    return switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'pdf' => 'application/pdf',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      _ => 'application/octet-stream',
    };
  }
}
