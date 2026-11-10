import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/app_colors.dart';
import '../data/services.dart';
import '../domain/video_request.dart';

/// 画像として表示できる添付か（拡張子で判定）。
bool isImageAttachment(Attachment a) {
  final ext = a.name.split('.').last.toLowerCase();
  return const {'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(ext);
}

/// 依頼の添付のうち、サムネイルに使うもの：最初に添付された動画または画像。なければ null。
Attachment? thumbnailAttachment(VideoRequest r) {
  for (final a in r.attachments) {
    if (a.kind == 'video' || isImageAttachment(a)) return a;
  }
  return null;
}

/// 添付のサムネイル。画像はそのまま、動画は最初の1コマ（再生はしない）を表示する。
/// 読み込めない間・失敗したときは、薄い枠にカメラのアイコンを出す。
class AttachmentThumb extends StatefulWidget {
  const AttachmentThumb({super.key, required this.attachment});

  final Attachment? attachment;

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
      final url = await (_urls[a.path] ??= Services.repo.downloadUrl(a.path));
      if (!mounted) return;
      if (a.kind == 'video') {
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
      _urls.remove(a.path);
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
        const Center(
            child: Icon(Icons.play_circle_outline,
                size: 40, color: AppColors.white)),
      ]);
    } else if (_url != null) {
      content = Image.network(_url!,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder);
    } else {
      content = _failed || widget.attachment == null
          ? _placeholder
          : const Center(
              child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.white)));
    }
    return ColoredBox(
        color: AppColors.white.withValues(alpha: 0.08), child: content);
  }
}
