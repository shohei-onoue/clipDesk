import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'storage_service.dart';

/// 幅の上限（ピクセル）。一覧のカードに十分で、数十KBに収まる大きさ。
const _maxWidth = 360;

String _mime(String name) {
  final ext = name.split('.').last.toLowerCase();
  return switch (ext) {
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    _ => 'video/mp4',
  };
}

/// 動画の最初の1コマ（0.5秒付近）をJPEGにする。作れなかったときは null（動画の保存は止めない）。
Future<Uint8List?> makeVideoThumbnail(UploadFile f) async {
  String? url;
  try {
    final bytes = await f.read();
    final blob =
        web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: _mime(f.name)));
    url = web.URL.createObjectURL(blob);
    final video = web.document.createElement('video') as web.HTMLVideoElement
      ..muted = true
      ..preload = 'auto'
      ..setAttribute('playsinline', '')
      ..src = url;

    Future<void> once(String event) {
      final c = Completer<void>();
      void done(web.Event _) {
        if (!c.isCompleted) c.complete();
      }

      video.addEventListener(event, done.toJS);
      video.addEventListener(
          'error', ((web.Event _) => c.completeError('video error')).toJS);
      return c.future;
    }

    await once('loadeddata').timeout(const Duration(seconds: 10));
    final d = video.duration;
    final target = d.isFinite && d > 0 ? (d / 2 < 0.5 ? d / 2 : 0.5) : 0.0;
    if (target > 0) {
      final seeked = once('seeked');
      video.currentTime = target;
      await seeked.timeout(const Duration(seconds: 10));
    }
    final w = video.videoWidth, h = video.videoHeight;
    if (w == 0 || h == 0) return null;
    final scale = w > _maxWidth ? _maxWidth / w : 1.0;
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = (w * scale).round()
      ..height = (h * scale).round();
    (canvas.getContext('2d') as web.CanvasRenderingContext2D)
        .drawImage(video, 0, 0, canvas.width.toDouble(), canvas.height.toDouble());
    final out = Completer<web.Blob?>();
    canvas.toBlob(((web.Blob? b) => out.complete(b)).toJS, 'image/jpeg', 0.75.toJS);
    final jpeg = await out.future.timeout(const Duration(seconds: 10));
    if (jpeg == null) return null;
    final buf = await jpeg.arrayBuffer().toDart;
    return buf.toDart.asUint8List();
  } catch (_) {
    return null;
  } finally {
    if (url != null) web.URL.revokeObjectURL(url);
  }
}
