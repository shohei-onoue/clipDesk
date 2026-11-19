import 'dart:io';

import 'package:video_player/video_player.dart';

import 'storage_service.dart';

Future<VideoPlayerController> localVideoController(UploadFile f) async {
  final path = f.path;
  if (path == null) throw UnsupportedError('端末上のファイルの場所がありません');
  return VideoPlayerController.file(File(path));
}
