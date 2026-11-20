import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../data/services.dart';
import '../domain/video_request.dart';

/// 依頼確認画面の上部に置く、提出された動画のプレーヤー。
/// 画面を開いたあと（遷移後）に、自動で再生を始める。承認済みなら承認された版、
/// そうでなければ最新の版を出す。右下の資料アイコンで、依頼の情報を開く（[onDocs]）。
class SubmissionPlayer extends StatelessWidget {
  const SubmissionPlayer({super.key, required this.request, this.onDocs});
  final VideoRequest request;

  /// 右下の資料アイコンを押したとき。
  final VoidCallback? onDocs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Submission>>(
      stream: Services.repo.watchSubmissions(request.id),
      builder: (context, snap) {
        final subs = snap.data ?? const <Submission>[];
        Submission? pick;
        for (final s in subs) {
          if (request.approved
              ? s.version == request.approvedVersion
              : pick == null || s.version > pick.version) {
            pick = s;
          }
        }
        return _Frame(
          onDocs: onDocs,
          caption: pick == null
              ? null
              : '${pick.version == 1 ? '初稿' : '修正動画'}（v${pick.version}）${pick.version == request.approvedVersion ? '　承認済み' : ''}',
          child: pick == null
              ? Center(
                  child: Text(
                      snap.connectionState == ConnectionState.waiting
                          ? '読み込んでいます…'
                          : '提出された動画はありません',
                      style: AppText.dark(14, weight: FontWeight.w400)))
              : _Player(key: ValueKey(pick.path), path: pick.path),
        );
      },
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child, this.caption, this.onDocs});
  final Widget child;
  final String? caption;
  final VoidCallback? onDocs;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          color: Colors.black,
          height: screen.height * 0.42,
          child: Stack(fit: StackFit.expand, children: [
            child,
            if (onDocs != null)
              Positioned(
                right: 8,
                bottom: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: '依頼の資料を開く',
                    onPressed: onDocs,
                    icon: const Icon(Icons.description_outlined,
                        color: AppColors.white),
                  ),
                ),
              ),
          ]),
        ),
      ),
      if (caption != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(caption!,
              style: AppText.dark(12,
                  weight: FontWeight.w400,
                  color: AppColors.white.withValues(alpha: 0.7))),
        ),
    ]);
  }
}

class _Player extends StatefulWidget {
  const _Player({super.key, required this.path});
  final String path;

  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> {
  VideoPlayerController? _c;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = VideoPlayerController.networkUrl(
          Uri.parse(await Services.repo.downloadUrl(widget.path)));
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _c = c);
      // 画面を開いたあとに再生する。ブラウザが自動再生をふさいだときは、再生ボタンで始める。
      try {
        await c.play();
      } catch (_) {}
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
    if (_error != null) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('エラー：動画を再生できません。通信を確認して、もう一度開いてください',
            textAlign: TextAlign.center,
            style: AppText.dark(14, weight: FontWeight.w400)),
      ));
    }
    if (c == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.white));
    }
    return Column(children: [
      Expanded(
        child: Center(
            child: AspectRatio(
                aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))),
      ),
      VideoProgressIndicator(c, allowScrubbing: true),
      Row(children: [
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: c,
          builder: (_, v, __) => IconButton(
            tooltip: v.isPlaying ? '一時停止' : '再生',
            color: AppColors.white,
            icon: Icon(v.isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () => v.isPlaying ? c.pause() : c.play(),
          ),
        ),
      ]),
    ]);
  }
}
