import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:video_player/video_player.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../data/services.dart';
import '../domain/video_request.dart';
import 'ruby_text.dart';

/// 依頼確認画面の上部に置く、提出された動画のプレーヤー。
/// 画面を開いたあと（遷移後）に、自動で再生を始める。承認済みなら承認された版、
/// そうでなければ最新の版を出す。右下の資料アイコンで、依頼の情報を開く（[onDocs]）。
class SubmissionPlayer extends StatelessWidget {
  const SubmissionPlayer(
      {super.key, required this.request, this.onDocs, this.expand = false});
  final VideoRequest request;

  /// true なら、置かれた場所の高さいっぱいに広げる（Expanded の中で使う）。
  final bool expand;

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
          // 動画があるときは、資料アイコンを操作列の右端に置く。動画がないときだけ、右下に重ねる。
          onDocs: pick == null ? onDocs : null,
          expand: expand,
          child: pick == null
              ? Center(
                  child: Text(
                      snap.connectionState == ConnectionState.waiting
                          ? '読み込んでいます…'
                          : '提出された動画はありません',
                      style: AppText.dark(14, weight: FontWeight.w400)))
              : VideoPanel(
                  key: ValueKey(pick.path),
                  path: pick.path,
                  onDocs: onDocs,
                  // 題名は、依頼時のタイトル。
                  title: request.brief.title.isEmpty
                      ? '（題名なし）'
                      : request.brief.title),
        );
      },
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child, this.onDocs, this.expand = false});
  final bool expand;
  final Widget child;
  final VoidCallback? onDocs;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final box = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: Colors.black,
        height: expand ? null : screen.height * 0.42,
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
                  icon:
                      Icon(Icons.description_outlined, color: AppColors.onDark),
                ),
              ),
            ),
        ]),
      ),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (expand) Expanded(child: box) else box,
    ]);
  }
}

/// 動画の再生パネル：動画、再生位置のバー（赤＋白い丸、ドラッグで移動）、
/// 再生・一時停止・秒数・題名。依頼確認画面の上部と、動画のダイアログで使う。
class VideoPanel extends StatefulWidget {
  const VideoPanel(
      {super.key,
      required this.path,
      required this.title,
      this.onDocs,
      this.audio = false});
  final String path;

  /// 音声だけのファイル。映像の代わりに音符を出す。
  final bool audio;

  /// 動画の題名（依頼時のタイトル）。操作列の下の行に出す。
  final String title;

  /// 操作列の右端の、依頼詳細（資料）アイコン。
  final VoidCallback? onDocs;

  @override
  State<VideoPanel> createState() => _VideoPanelState();
}

class _VideoPanelState extends State<VideoPanel> {
  VideoPlayerController? _c;
  Object? _error;

  /// つまみをドラッグしている間の位置（ミリ秒）。null ならドラッグしていない。
  double? _drag;

  /// 再生位置（ミリ秒）。ブラウザの動画から、0.2秒ごとに読み直す（値の通知に頼らない）。
  Timer? _tick;
  double _posMs = 0;
  bool _playing = false;

  /// 再生してよい状態か。一時停止を押した、または最後まで再生した後は false。
  /// ブラウザは、画面の表示・非表示やフォーカスの切り替えで、動画プレーヤーが勝手に再生を
  /// 再開することがある。再生してよくないときに再生が始まったら、止め直す。
  bool _wantPlay = true;

  void _guard(VideoPlayerController c) {
    final v = c.value;
    if (v.isCompleted) {
      _wantPlay = false;
      _pausedAt = null;
    }
    if (!_wantPlay && v.isPlaying) {
      // 止め直すまでに進んだぶんは、止めた位置へ戻す（一時停止中に動かさない）。
      c.pause().then((_) {
        final at = _pausedAt;
        if (at != null) c.seekTo(Duration(milliseconds: at.round()));
      });
    }
  }

  /// 一時停止した位置（ミリ秒）。最後まで再生したあとは null。
  double? _pausedAt;

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
      c.addListener(() => _guard(c));
      setState(() => _c = c);
      _tick = Timer.periodic(const Duration(milliseconds: 200), (_) => _sync());
      // 画面を開いたあとに再生する。ブラウザが自動再生をふさいだときは、再生ボタンで始める。
      try {
        await c.play();
      } catch (_) {}
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// 動画の今の位置と再生中かどうかを読み、画面（バー・秒数・ボタン）へ反映する。
  Future<void> _sync() async {
    final c = _c;
    if (c == null || !mounted || _drag != null) return;
    final p = await c.position;
    if (!mounted) return;
    final total = c.value.duration.inMilliseconds;
    final ended = total > 0 && (p?.inMilliseconds ?? 0) >= total - 50;
    final playing = c.value.isPlaying && !ended;
    final ms = (p?.inMilliseconds ?? 0).toDouble();
    if (ms != _posMs || playing != _playing) {
      setState(() {
        _posMs = ms;
        _playing = playing;
      });
    }
  }

  Future<void> _play() async {
    _wantPlay = true;
    _pausedAt = null;
    final c = _c!;
    // 最後まで再生したあとは、最初から再生する。
    if (c.value.duration.inMilliseconds > 0 &&
        _posMs >= c.value.duration.inMilliseconds - 50) {
      await c.seekTo(Duration.zero);
    }
    await c.play();
    await _sync();
  }

  Future<void> _pause() async {
    _wantPlay = false;
    await _c!.pause();
    _pausedAt = (await _c!.position)?.inMilliseconds.toDouble();
    await _sync();
  }

  @override
  void dispose() {
    _tick?.cancel();
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
      return Center(child: CircularProgressIndicator(color: AppColors.onDark));
    }
    return Column(children: [
      Expanded(
        child: Center(
            child: widget.audio
                ? Icon(Icons.music_note, size: 96, color: AppColors.onDark)
                : AspectRatio(
                    aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))),
      ),
      // 再生位置のバー：赤い線に白い丸。丸をタップして左右に動かすと、再生位置が動く。
      ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: c,
        builder: (_, v, __) {
          final total = v.duration.inMilliseconds.toDouble();
          final pos =
              (_drag ?? _posMs).clamp(0, total > 0 ? total : 1).toDouble();
          return Column(children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: const Color(0xFFFF0000),
                inactiveTrackColor: AppColors.onDark.withValues(alpha: 0.3),
                thumbColor: AppColors.onDark,
                overlayColor: AppColors.onDark.withValues(alpha: 0.16),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                trackShape: const RectangularSliderTrackShape(),
              ),
              child: SizedBox(
                height: 24,
                child: Slider(
                  min: 0,
                  max: total > 0 ? total : 1,
                  value: pos,
                  onChangeStart: (x) => setState(() => _drag = x),
                  onChanged: total > 0
                      ? (x) {
                          setState(() => _drag = x);
                          c.seekTo(Duration(milliseconds: x.round()));
                        }
                      : null,
                  onChangeEnd: (x) async {
                    await c.seekTo(Duration(milliseconds: x.round()));
                    _posMs = x;
                    if (!_wantPlay) _pausedAt = x;
                    if (mounted) setState(() => _drag = null);
                  },
                ),
              ),
            ),
            // 操作列：再生、一時停止、再生中の秒数 / 全体の秒数。右端に依頼詳細（資料）アイコン。
            Row(children: [
              IconButton(
                tooltip: '再生',
                // 押せる状態は常に保ち、今の状態のほうを濃く見せる。
                color: _playing
                    ? AppColors.onDark.withValues(alpha: 0.4)
                    : AppColors.onDark,
                icon: const Icon(Icons.play_arrow),
                onPressed: _play,
              ),
              IconButton(
                tooltip: '一時停止',
                color: _playing
                    ? AppColors.onDark
                    : AppColors.onDark.withValues(alpha: 0.4),
                icon: const Icon(Icons.pause),
                onPressed: _pause,
              ),
              Text(
                  '${_fmt(Duration(milliseconds: pos.round()))} / ${_fmt(v.duration)}',
                  style: AppText.dark(13, weight: FontWeight.w400)),
              const Spacer(),
              if (widget.onDocs != null)
                IconButton(
                  tooltip: '依頼の詳細を開く',
                  onPressed: widget.onDocs,
                  icon:
                      Icon(Icons.description_outlined, color: AppColors.onDark),
                ),
            ]),
            // 動画の題名：操作列の下に1行（依頼時のタイトル）。
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(children: [
                Expanded(
                  child: Text(widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.dark(14)),
                ),
              ]),
            ),
          ]);
        },
      ),
    ]);
  }

  /// 秒数の表示（1時間未満は m:ss、以上は h:mm:ss）。
  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }
}
