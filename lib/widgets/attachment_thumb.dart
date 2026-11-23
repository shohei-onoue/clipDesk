import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/app_colors.dart';
import '../data/local_video.dart';
import '../data/services.dart';
import '../data/storage_service.dart';
import '../domain/video_request.dart';

/// 画像として表示できる添付か（拡張子で判定）。
bool isImageAttachment(Attachment a) {
  final ext = a.name.split('.').last.toLowerCase();
  return const {'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(ext);
}

/// 添付の種類（拡張子で判定。動画は登録時の種別も見る）。
enum AttachmentType { video, image, audio, other }

AttachmentType attachmentTypeOf(Attachment a) {
  final ext = a.name.split('.').last.toLowerCase();
  if (a.kind == 'video' || const {'mp4', 'mov', 'm4v', 'webm'}.contains(ext)) {
    return AttachmentType.video;
  }
  if (isImageAttachment(a)) return AttachmentType.image;
  if (const {'mp3', 'wav', 'm4a', 'aac'}.contains(ext)) {
    return AttachmentType.audio;
  }
  return AttachmentType.other;
}

/// 依頼の添付のうち、サムネイルに使うもの：最初に添付された動画または画像。なければ null。
Attachment? thumbnailAttachment(VideoRequest r) {
  for (final a in r.attachments) {
    if (a.kind == 'video' || isImageAttachment(a)) return a;
  }
  return null;
}

/// 添付のサムネイル。画像はそのまま、動画は静止画サムネイル（[Attachment.thumbPath]）を表示する。
/// 一覧では動画プレーヤーを起動しない（通信・描画が重いため）。静止画がない動画は、薄い枠に
/// 再生アイコンを出す（動画は、タップして開けば従来どおり再生できる）。
/// [allowVideoPreview] が true のときだけ、静止画がない動画を、動画の最初の1コマで出す
/// （1件ずつ開く詳細の画面用）。
class AttachmentThumb extends StatefulWidget {
  const AttachmentThumb(
      {super.key, required this.attachment, this.allowVideoPreview = false});

  final Attachment? attachment;
  final bool allowVideoPreview;

  @override
  State<AttachmentThumb> createState() => _AttachmentThumbState();
}

class _AttachmentThumbState extends State<AttachmentThumb> {
  /// 同じ添付のURL取得を、カードの再構築のたびにやり直さない。
  static final _urls = <String, Future<String>>{};

  VideoPlayerController? _video;
  String? _url;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = widget.attachment;
    if (a == null) return;
    try {
      final isVideo = a.kind == 'video';
      if (isVideo && a.thumbPath == null && !widget.allowVideoPreview) {
        return; // 静止画がない動画は、代替表示のまま（動画を読み込まない）。
      }
      final src = isVideo && a.thumbPath != null ? a.thumbPath! : a.path;
      final url = await (_urls[src] ??= Services.repo.downloadUrl(src));
      if (!mounted) return;
      if (isVideo && a.thumbPath == null) {
        final c = VideoPlayerController.networkUrl(Uri.parse(url));
        await c.initialize();
        await c.setVolume(0);
        if (!mounted) {
          await c.dispose();
          return;
        }
        setState(() => _video = c);
      } else {
        setState(() => _url = url);
      }
    } catch (_) {
      _urls.remove(a.thumbPath ?? a.path);
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  Widget get _placeholder => Center(
        child: Icon(Icons.videocam_outlined,
            size: 40, color: AppColors.white.withValues(alpha: 0.55)),
      );

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (_video != null) {
      final size = _video!.value.size;
      content = Stack(fit: StackFit.expand, children: [
        FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
              width: size.width,
              height: size.height,
              child: VideoPlayer(_video!)),
        ),
        Center(
            child: Icon(Icons.play_circle_outline,
                size: 40, color: AppColors.white)),
      ]);
    } else if (_url != null) {
      content = Stack(fit: StackFit.expand, children: [
        Image.network(_url!,
            fit: BoxFit.cover,
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            errorBuilder: (_, __, ___) => _placeholder),
        if (widget.attachment?.kind == 'video')
          Center(
              child: Icon(Icons.play_circle_outline,
                  size: 40, color: AppColors.white)),
      ]);
    } else {
      final a = widget.attachment;
      final noPreview = a != null &&
          a.kind == 'video' &&
          a.thumbPath == null &&
          !widget.allowVideoPreview;
      content = _failed || a == null || noPreview
          ? _placeholder
          : Center(
              child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.white)));
    }
    return ColoredBox(color: AppColors.gray, child: content);
  }
}

/// 送信前の端末上の動画の、最初の1コマ（タップで再生するための印つき）。
class LocalVideoThumb extends StatefulWidget {
  const LocalVideoThumb({super.key, required this.file});
  final UploadFile file;

  @override
  State<LocalVideoThumb> createState() => _LocalVideoThumbState();
}

class _LocalVideoThumbState extends State<LocalVideoThumb> {
  VideoPlayerController? _video;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await localVideoController(widget.file);
      await c.initialize();
      await c.setVolume(0);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _video = c);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _video;
    if (v == null) {
      return Center(
        child: _failed
            ? Icon(Icons.play_circle_outline, color: AppColors.white)
            : SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.white)),
      );
    }
    final size = v.value.size;
    return Stack(fit: StackFit.expand, children: [
      FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
            width: size.width, height: size.height, child: VideoPlayer(v)),
      ),
      Center(
          child: Icon(Icons.play_circle_outline,
              size: 28, color: AppColors.white)),
    ]);
  }
}
