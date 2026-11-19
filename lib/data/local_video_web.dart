import 'dart:js_interop';

import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;

import 'storage_service.dart';

String _mime(String name) {
  final ext = name.split('.').last.toLowerCase();
  return switch (ext) {
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    _ => 'video/mp4',
  };
}

Future<VideoPlayerController> localVideoController(UploadFile f) async {
  final bytes = await f.read();
  final blob =
      web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: _mime(f.name)));
  return VideoPlayerController.networkUrl(
      Uri.parse(web.URL.createObjectURL(blob)));
}
