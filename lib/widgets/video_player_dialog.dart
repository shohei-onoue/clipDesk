import 'package:flutter/material.dart' hide Text;
import 'package:video_player/video_player.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../data/local_video.dart';
import '../data/services.dart';
import '../domain/video_request.dart';
import 'attachment_thumb.dart';
import 'submission_player.dart';
import '../data/storage_service.dart';
import 'ruby_text.dart';

/// Storage上の動画（[audio] なら音声）を再生するダイアログ。YouTube風：黒い面に動画、赤いバーと白い丸、
/// 再生・一時停止・秒数、題名。右上の×で閉じる。
Future<void> showVideoDialog(BuildContext context,
    {required String path,
    required String title,
    bool audio = false,
    VoidCallback? onDocs}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final screen = MediaQuery.sizeOf(ctx);
      return Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: screen.width < 560 ? double.maxFinite : 480,
          height: screen.height * 0.85,
          child: Stack(children: [
            VideoPanel(
                key: ValueKey(path),
                path: path,
                title: title,
                audio: audio,
                onDocs: onDocs),
            Positioned(
              right: 4,
              top: 4,
              child: IconButton(
                tooltip: '閉じる',
                onPressed: () => Navigator.of(ctx).pop(),
                style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.55)),
                icon: Icon(Icons.close, color: AppColors.on(Colors.black)),
              ),
            ),
          ]),
        ),
      );
    },
  );
}

/// 添付ファイルをダイアログで開く。動画・音声は再生、画像は表示する。
/// それ以外（資料など）は、見られないことを伝え、[onDownload] があればダウンロードを案内する。
Future<void> showAttachmentDialog(BuildContext context,
    {required Attachment attachment, VoidCallback? onDownload}) {
  final name = attachment.name;
  switch (attachmentTypeOf(attachment)) {
    case AttachmentType.video:
      return showVideoDialog(context, path: attachment.path, title: name);
    case AttachmentType.audio:
      return showVideoDialog(context,
          path: attachment.path, title: name, audio: true);
    case AttachmentType.image:
      return showDialog<void>(
        context: context,
        builder: (_) => _ImageDialog(attachment: attachment),
      );
    case AttachmentType.other:
      return showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.ink,
          title: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.dark(18)),
          content: Text(
              onDownload == null
                  ? 'この形式のファイルは、アプリ内で開けません。ダウンロードは編集者だけができます'
                  : 'この形式のファイルは、アプリ内で開けません。ダウンロードして開いてください',
              style: AppText.dark(14, weight: FontWeight.w400)),
          actions: [
            if (onDownload != null)
              TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onDownload();
                  },
                  child: Text('ダウンロード',
                      style:
                          AppText.dark(14, color: AppColors.on(Colors.black)))),
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('閉じる',
                    style:
                        AppText.dark(14, color: AppColors.on(Colors.black)))),
          ],
        ),
      );
  }
}

class _ImageDialog extends StatelessWidget {
  const _ImageDialog({required this.attachment});
  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    // AlertDialog は中身の幅を測るため、画像の読み込み中にレイアウトが壊れる。Dialog で組む。
    return Dialog(
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: screen.width < 560 ? screen.width : 480,
            maxHeight: screen.height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.dark(18)),
              const SizedBox(height: 16),
              Flexible(
                child: FutureBuilder<String>(
                  future: Services.repo.downloadUrl(attachment.path),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Text('エラー：画像を開けません。通信を確認して、もう一度開いてください',
                          style: AppText.dark(14, weight: FontWeight.w400));
                    }
                    if (!snap.hasData) {
                      return SizedBox(
                          height: 120,
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.on(Colors.black))));
                    }
                    return Image.network(
                      snap.data!,
                      fit: BoxFit.contain,
                      // Webで別オリジンの画像を、ブラウザ標準の <img> で出す（CORS設定が無くても見られる）。
                      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                      loadingBuilder: (_, child, p) => p == null
                          ? child
                          : SizedBox(
                              height: 120,
                              child: Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.on(Colors.black)))),
                      errorBuilder: (_, __, ___) => Text(
                          'エラー：画像を表示できません。通信を確認して、もう一度開いてください',
                          style: AppText.dark(14, weight: FontWeight.w400)),
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('閉じる',
                        style: AppText.dark(14,
                            color: AppColors.on(Colors.black)))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 送信前の端末上の動画を再生するダイアログ。
Future<void> showLocalVideoDialog(BuildContext context,
    {required UploadFile file, required String title}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _VideoDialog(title: title, create: () => localVideoController(file)),
  );
}

class _VideoDialog extends StatefulWidget {
  const _VideoDialog({required this.create, required this.title});

  final Future<VideoPlayerController> Function() create;
  final String title;

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  VideoPlayerController? _c;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await widget.create();
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _c = c);
      await c.play();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    // 画面からはみ出さないよう、幅は画面内、動画の高さは画面の半分までに収める。
    final screen = MediaQuery.sizeOf(context);
    return AlertDialog(
      backgroundColor: AppColors.ink,
      title: Text(widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.dark(18)),
      content: SizedBox(
        width: screen.width < 560 ? double.maxFinite : 480,
        child: _error != null
            ? Text('エラー：動画を再生できません（$_error）。通信を確認して、もう一度開いてください',
                style: AppText.dark(14, weight: FontWeight.w400))
            : c == null
                ? SizedBox(
                    height: 120,
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.on(Colors.black))))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints:
                            BoxConstraints(maxHeight: screen.height * 0.5),
                        child: AspectRatio(
                            aspectRatio: c.value.aspectRatio,
                            child: VideoPlayer(c)),
                      ),
                      VideoProgressIndicator(c, allowScrubbing: true),
                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: c,
                        builder: (_, v, __) => IconButton(
                          tooltip: v.isPlaying ? '一時停止' : '再生',
                          color: AppColors.on(Colors.black),
                          icon: Icon(
                              v.isPlaying ? Icons.pause : Icons.play_arrow),
                          onPressed: () => v.isPlaying ? c.pause() : c.play(),
                        ),
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('閉じる',
                style: AppText.dark(14, color: AppColors.on(Colors.black)))),
      ],
    );
  }
}
