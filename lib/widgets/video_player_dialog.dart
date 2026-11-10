import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../data/services.dart';

/// Storage上の動画を再生するダイアログ。
Future<void> showVideoDialog(BuildContext context,
    {required String path, required String title}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _VideoDialog(path: path, title: title),
  );
}

class _VideoDialog extends StatefulWidget {
  const _VideoDialog({required this.path, required this.title});
  final String path;
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
      final url = await Services.repo.downloadUrl(widget.path);
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
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
    return AlertDialog(
      backgroundColor: AppColors.white.withValues(alpha: 0.08),
      title: Text(widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.dark(18)),
      content: SizedBox(
        width: 480,
        child: _error != null
            ? Text('エラー：動画を再生できません（$_error）。通信を確認して、もう一度開いてください',
                style: AppText.dark(14, weight: FontWeight.w400))
            : c == null
                ? const SizedBox(
                    height: 120,
                    child: Center(
                        child:
                            CircularProgressIndicator(color: AppColors.white)))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AspectRatio(
                          aspectRatio: c.value.aspectRatio,
                          child: VideoPlayer(c)),
                      VideoProgressIndicator(c, allowScrubbing: true),
                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: c,
                        builder: (_, v, __) => IconButton(
                          tooltip: v.isPlaying ? '一時停止' : '再生',
                          color: AppColors.white,
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
            child:
                Text('閉じる', style: AppText.dark(14, color: AppColors.white))),
      ],
    );
  }
}
