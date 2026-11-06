import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../widgets/intro_painter.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';

/// 00 ログイン（フォーム表示）
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _keep = false;
  bool _showForm = false;
  bool _paused = false;
  late final AnimationController _intro;
  final _time = ValueNotifier<double>(0);
  final _hide = ValueNotifier<double>(0);
  late final VideoPlayerController _video;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 19700),
    )..addListener(() => _time.value = _intro.value * 19.7);
    _video = VideoPlayerController.asset('assets/video.mp4');
    _initializeVideo();
    _intro.forward();
  }

  Future<void> _initializeVideo() async {
    try {
      await _video.initialize();
      await _video.setLooping(true);
      await _video.setVolume(0);
      if (!mounted) return;
      if (!_paused) await _video.play();
      if (mounted) setState(() {});
    } catch (error) {
      // ローカル動画が読めない場合もログインへ進める。
      debugPrint('Opening video: $error');
      if (mounted) _openForm();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _paused = true;
      _intro.value = 1;
      _showForm = true;
      _hide.value = 1;
      if (_video.value.isInitialized) _video.pause();
    }
  }

  void _openForm() {
    _intro.value = 1;
    _hide.value = 1;
    setState(() => _showForm = true);
  }

  void _replay() {
    FocusScope.of(context).unfocus();
    _hide.value = 0;
    setState(() => _showForm = false);
    _intro.value = 0;
    if (!_paused) _intro.forward();
  }

  void _togglePlayback() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _intro.stop();
      _video.pause();
    } else {
      _intro.forward();
      if (_video.value.isInitialized) _video.play();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _time.dispose();
    _hide.dispose();
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final size = MediaQuery.sizeOf(context);
    final titleSize = introTitleSize(size.width);
    // 入力欄とログインボタンの高さ（共通）。
    final fieldHeight = r.y(46);
    return Scaffold(
      backgroundColor: AppColors.loginBg,
      body: Stack(
        children: [
          if (_video.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _video.value.size.width,
                  height: _video.value.size.height,
                  child: VideoPlayer(_video),
                ),
              ),
            ),
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _intro.value = 1,
              child: CustomPaint(painter: IntroPainter(_time, _hide)),
            ),
          ),
          if (!_showForm)
            Positioned(
              top: r.y(475),
              left: r.x(133.5),
              width: r.x(123),
              height: r.y(50),
              child: AnimatedBuilder(
                animation: _intro,
                builder: (context, child) {
                  final alpha = ((_time.value - IntroPainter.fadeStart) /
                          IntroPainter.fadeLen)
                      .clamp(0.0, 1.0);
                  return ExcludeSemantics(
                    excluding: alpha == 0,
                    child: ExcludeFocus(
                      excluding: alpha == 0,
                      child: IgnorePointer(
                        ignoring: alpha == 0,
                        child: Opacity(opacity: alpha, child: child),
                      ),
                    ),
                  );
                },
                child: ElevatedButton(
                  onPressed: _openForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('LOGIN'),
                ),
              ),
            ),
          Positioned(
            top: r.y(14),
            right: r.x(20),
            child: Row(
              children: [
                _Pill(label: 'REPLAY', onTap: _replay),
                SizedBox(width: r.x(8)),
                _Pill(label: 'SKIP', onTap: _openForm),
              ],
            ),
          ),
          Positioned(
            left: r.x(20),
            bottom: r.y(20),
            child: _Pill(
              label: _paused ? 'PLAY' : 'PAUSE',
              onTap: _togglePlayback,
            ),
          ),
          if (_showForm)
            Positioned(
              // 入力欄の位置は、タイトルを消す前（オープニング最後の「Clip Desk」の下）と同じ。
              top: introTitleCenterY(size.height) +
                  titleSize / 2 +
                  r.y(10) +
                  r.x(13) +
                  r.y(14),
              left: r.x(24),
              width: r.x(342),
              child: Padding(
                padding: EdgeInsets.fromLTRB(r.x(2), 0, r.x(2), r.y(24)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Field(hint: 'メールアドレス', height: fieldHeight),
                    SizedBox(height: r.y(14)),
                    _Field(hint: 'パスワード', obscure: true, height: fieldHeight),
                    SizedBox(height: r.y(14)),
                    SizedBox(
                      height: fieldHeight,
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context).pushReplacementNamed('/home'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(r.x(6))),
                        ),
                        child: Text('ログイン',
                            style: AppText.noto(r.x(13),
                                color: Colors.white, height: 1.3)),
                      ),
                    ),
                    SizedBox(height: r.y(14)),
                    GestureDetector(
                      onTap: () => setState(() => _keep = !_keep),
                      child: Padding(
                        padding: EdgeInsets.only(top: r.y(10)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: r.x(20),
                              height: r.x(20),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                                borderRadius: BorderRadius.circular(r.x(2)),
                              ),
                              child: _keep
                                  ? Icon(Icons.check,
                                      size: r.x(16), color: Colors.white)
                                  : null,
                            ),
                            SizedBox(width: r.x(8)),
                            Text('ログイン状態を維持する',
                                style: AppText.noto(r.x(12),
                                    weight: FontWeight.w500,
                                    color: Colors.white,
                                    height: 1.3)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.x(18), vertical: r.y(8)),
        decoration: BoxDecoration(
          color: const Color(0xD1111111),
          border: Border.all(color: const Color(0xE6111111)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style:
                AppText.oswald(r.x(13), height: 16.9 / 13, letterSpacing: 1.5)),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(
      {required this.hint, required this.height, this.obscure = false});

  final String hint;
  final double height;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return SizedBox(
      height: height,
      child: TextField(
        obscureText: obscure,
        // 高さいっぱいに広げ、文字は上下中央に置く（ボタンと同じ高さにそろえる）。
        expands: true,
        maxLines: null,
        minLines: null,
        textAlignVertical: TextAlignVertical.center,
        style: AppText.noto(r.x(13), weight: FontWeight.w400, height: 1.3),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: hint,
          hintStyle: AppText.noto(r.x(13),
              weight: FontWeight.w400, color: AppColors.hint, height: 1.3),
          contentPadding: EdgeInsets.symmetric(horizontal: r.x(14)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(r.x(6)),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
