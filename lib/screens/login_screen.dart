import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:video_player/video_player.dart';

import '../widgets/intro_painter.dart';

import '../core/app_colors.dart';
import '../core/boot.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../widgets/ruby_text.dart';

/// 00 ログイン（フォーム表示）
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _keep = false;
  bool _busy = false;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _showPassword = false;

  /// 入力中に見えたキーボードの高さの最大値。メール欄とパスワード欄で
  /// キーボードの高さが違っても、フォームの位置が変わらないようにそろえる。
  double _keyboardMax = 0;

  /// ログインフォームは、読み込み（Firebase など）が終わるまで表示しない。
  /// 終わったら、動画の途中でも、タップなしで表示する。
  bool get _showForm => Boot.isReady;
  late final AnimationController _intro;
  final _time = ValueNotifier<double>(0);
  final _hide = ValueNotifier<double>(0);
  VideoPlayerController? _video;
  bool _disposed = false;

  /// ログイン認証エラーのときに鳴らす音声（assets/voice.mp3）。
  late final VideoPlayerController _voice;
  bool _voiceReady = false;

  /// ブラウザ（iPhone Safariなど）が自動再生を止めたとき、最初のタップで再生する。
  bool _needsGesture = false;

  @override
  void initState() {
    super.initState();
    Boot.state.addListener(_onBootChanged);
    _emailFocus.addListener(_onFocusChange);
    _passwordFocus.addListener(_onFocusChange);
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 18700),
      // 「動きを減らす」ONの端末では、標準だとアニメが約20倍速で終わってしまうため、そのままの速さで流す。
      animationBehavior: AnimationBehavior.preserve,
    )..addListener(() => _time.value = _intro.value * 18.7);
    if (Boot.isReady) {
      // ログアウトして戻ったときなど、読み込み済みなら、すぐフォームを出す（動画は流さない）。
      _intro.value = 1;
      _hide.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _onBootChanged());
    } else {
      _intro.forward();
      // 動画は最初の画面を出したあとに用意する。静止画を先に出し、動画の準備でログインを待たせない。
      WidgetsBinding.instance.addPostFrameCallback((_) => _initializeVideo());
    }
    _initializeVoice();
  }

  Future<void> _initializeVideo() async {
    if (_disposed || Boot.isReady) return;
    final video = VideoPlayerController.asset('assets/video_web.mp4');
    _video = video;
    try {
      await video.initialize();
      await video.setLooping(true);
      await video.setVolume(0);
      if (_disposed || Boot.isReady) return _releaseVideo();
      try {
        await video.play();
      } catch (error) {
        debugPrint('Opening video autoplay blocked: $error');
        _needsGesture = true;
      }
      if (mounted) setState(() {});
    } catch (error) {
      // 動画が読めなくても静止画のまま進める（ログインは待たせない）。
      debugPrint('Opening video: $error');
      _releaseVideo();
    }
  }

  /// 背景動画を止めて、再生のためのリソースを解放する。
  void _releaseVideo() {
    final v = _video;
    _video = null;
    v?.pause();
    v?.dispose();
  }

  /// 読み込みの状態が変わったとき。終わったら、動画を止めてフォームを出す。
  /// 招待リンクなら登録フォームへ、自動ログイン済み（デバッグ）ならメイン画面へ、起動後の1回だけ進む。
  void _onBootChanged() {
    if (!mounted) return;
    if (Boot.isReady) {
      final route = Boot.takeInitialRoute();
      if (route != null) {
        Navigator.of(context).pushReplacementNamed(route);
        return;
      }
      _intro.value = 1;
      _hide.value = 1;
      _releaseVideo();
    }
    setState(() {});
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeVoice() async {
    _voice = VideoPlayerController.asset('assets/voice.mp3');
    try {
      await _voice.initialize();
      await _voice.setLooping(false);
      _voiceReady = true;
    } catch (e) {
      debugPrint('Error voice: $e');
    }
  }

  /// iPhone Safariは、利用者の操作の中で一度再生しないと、あとから自動で音を鳴らせない。
  /// ログインボタンを押した時点で、音量0で再生して止めておく（鳴らす準備）。
  Future<void> _primeVoice() async {
    if (!_voiceReady) return;
    try {
      await _voice.setVolume(0);
      await _voice.play();
      await _voice.pause();
      await _voice.seekTo(Duration.zero);
    } catch (e) {
      debugPrint('Prime voice: $e');
    }
  }

  /// ログインに失敗したときの音声を鳴らす。
  Future<void> _playErrorVoice() async {
    if (!_voiceReady) return;
    try {
      await _voice.seekTo(Duration.zero);
      await _voice.setVolume(1);
      await _voice.play();
    } catch (e) {
      debugPrint('Error voice play: $e');
    }
  }

  /// メールアドレスとパスワードで Firebase Authentication にログインする。
  Future<void> _login() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('メールアドレスとパスワードを入力してください');
      // 押した操作の中で鳴らす（iPhone Safari でも再生できる）。
      _playErrorVoice();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    _primeVoice();
    final auth = FirebaseAuth.instance;
    try {
      // ONなら端末に保存（ログアウトまで保持）、OFFならタブを閉じるまで。
      // 保存先が使えない環境（iPhoneのプライベートブラウズ、Web以外の端末など）では
      // 保存方法の指定に失敗するが、ログインそのものは止めずに続ける。
      try {
        await auth.setPersistence(
          _keep ? Persistence.LOCAL : Persistence.SESSION,
        );
      } catch (e) {
        debugPrint('ログイン状態の保存方法を設定できませんでした: $e');
      }
      final cred = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _saveUser(cred.user);
    } on FirebaseAuthException catch (e) {
      _showError(_errorMessage(e.code));
      _playErrorVoice();
      if (mounted) setState(() => _busy = false);
      return;
    } catch (e) {
      debugPrint('ログインに失敗しました: $e');
      _showError('ログインできませんでした（${e.runtimeType}）。通信を確認してください');
      _playErrorVoice();
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/menu');
  }

  /// ログイン成功時に、Firestore の users/{uid} へ email・name・updatedAt を保存する。
  /// merge 保存なので、すでにある項目は消えない。name は Authentication に
  /// 表示名があるときだけ書く（無いときに空で上書きして消さないため）。
  /// 保存に失敗しても、ログイン自体は続ける。
  Future<void> _saveUser(User? user) async {
    if (user == null) return;
    final name = user.displayName?.trim();
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        if (name != null && name.isNotEmpty) 'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
        // 使わなくなった項目は、ログイン時に自分の分を消す。
        'phone': FieldValue.delete(),
        'displayName': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('users/${user.uid} の保存に失敗しました: $e');
    }
  }

  String _errorMessage(String code) {
    switch (code) {
      case 'wrong-password':
        return 'パスワードが違います';
      case 'user-not-found':
        return 'メールアドレスが違います';
      case 'invalid-credential':
        return 'メールアドレスまたはパスワードが違います';
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません';
      case 'user-disabled':
        return 'このアカウントは使えません';
      case 'too-many-requests':
        return '試行回数が多すぎます。しばらくしてからやり直してください';
      case 'network-request-failed':
        return '通信できませんでした。ネットワークを確認してください';
      default:
        return 'ログインできませんでした（$code）';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    Boot.state.removeListener(_onBootChanged);
    _disposed = true;
    _intro.dispose();
    _time.dispose();
    _hide.dispose();
    _releaseVideo();
    _voice.dispose();
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final size = MediaQuery.sizeOf(context);
    final titleSize = introTitleSize(size.width);
    // 入力欄とログインボタンの高さ（共通）。
    final fieldHeight = r.y(46);
    // キーボードが出ているとき、入力欄とログインボタンがキーボードに隠れないよう、
    // フォームをキーボードの上へ持ち上げる。
    final inputting = _emailFocus.hasFocus || _passwordFocus.hasFocus;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (!inputting && inset == 0) _keyboardMax = 0;
    if (inset > _keyboardMax) _keyboardMax = inset;
    // 入力中は、どちらの欄でも同じ配置（最大のキーボード高さ）にする。
    final keyboard = (inputting || inset > 0) ? _keyboardMax : 0.0;
    final formTop = introTitleCenterY(size.height) +
        titleSize / 2 +
        r.y(10) +
        r.x(13) +
        r.y(14);
    final formHeight = fieldHeight * 3 + r.y(14) * 2; // 入力2つ + ボタン + すき間
    final visibleTop = math.max(
      r.y(60),
      math.min(formTop, size.height - keyboard - formHeight - r.y(12)),
    );
    return Scaffold(
      // 位置は上で自分で計算するため、Scaffoldによる縮小は使わない。
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.bg,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          // iPhone Safari などが自動再生を止めたとき、最初のタップで動画を始める。
          if (_needsGesture) {
            _needsGesture = false;
            _video?.play().then((_) {
              if (mounted) setState(() {});
            });
          }
        },
        child: Stack(
          children: [
            // 軽い静止画を先に出す。動画の準備ができて再生が始まったら、その上に重ねる。
            Positioned.fill(
              child: Image.asset(
                'assets/intro_poster.jpg',
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            if (_video != null &&
                _video!.value.isInitialized &&
                _video!.value.isPlaying)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _video!.value.size.width,
                    height: _video!.value.size.height,
                    child: IgnorePointer(child: VideoPlayer(_video!)),
                  ),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                  child: CustomPaint(painter: IntroPainter(_time, _hide))),
            ),
            if (Boot.state.value == BootState.loading)
              Positioned(
                left: 0,
                right: 0,
                bottom: r.y(40),
                child: ExcludeSemantics(
                  child: Center(
                    child: Text('読み込み中…',
                        style: AppText.noto(r.x(13),
                            color: AppColors.white.withValues(alpha: 0.7),
                            height: 1.3)),
                  ),
                ),
              ),
            if (Boot.state.value == BootState.failed)
              Positioned(
                left: r.x(24),
                right: r.x(24),
                bottom: r.y(60),
                child: Center(
                  child: SizedBox(
                    width: r.x(342),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('エラー：アプリを起動できませんでした。通信を確認して、もう一度お試しください。',
                            textAlign: TextAlign.center,
                            style: AppText.noto(r.x(14),
                                color: AppColors.white, height: 1.5)),
                        SizedBox(height: r.y(12)),
                        SizedBox(
                          height: fieldHeight,
                          child: ElevatedButton(
                            onPressed: Boot.retry,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.blue,
                              foregroundColor: AppColors.onBlue,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(r.x(6))),
                            ),
                            child: Text('再試行',
                                style: AppText.noto(r.x(13),
                                    color: AppColors.onBlue, height: 1.3)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_showForm)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                // キーボードが出ていないときは、タイトルを消す前（オープニング最後の「Clip Desk」の下）と同じ位置。
                top: visibleTop,
                // 画面の左右中央に置く（広い画面でも中央）。
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: r.x(342),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(r.x(2), 0, r.x(2), r.y(24)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Field(
                            hint: 'メールアドレス',
                            height: fieldHeight,
                            controller: _email,
                            focusNode: _emailFocus,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          SizedBox(height: r.y(14)),
                          _Field(
                            hint: 'パスワード',
                            height: fieldHeight,
                            controller: _password,
                            focusNode: _passwordFocus,
                            obscure: !_showPassword,
                            suffix: IconButton(
                              tooltip: _showPassword ? 'パスワードを隠す' : 'パスワードを表示',
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints.tightFor(
                                  width: r.x(44), height: fieldHeight),
                              iconSize: r.x(22),
                              color: AppColors.onLight.withValues(alpha: 0.5),
                              icon: Icon(_showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () => setState(
                                  () => _showPassword = !_showPassword),
                            ),
                          ),
                          SizedBox(height: r.y(14)),
                          SizedBox(
                            height: fieldHeight,
                            child: ElevatedButton(
                              onPressed: _busy ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.blue,
                                foregroundColor: AppColors.onBlue,
                                // ログイン中は黒（ink）にして、文字の代わりに回るアイコンを出す。
                                disabledBackgroundColor: AppColors.bg,
                                disabledForegroundColor: AppColors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(r.x(6))),
                              ),
                              child: _busy
                                  ? SizedBox(
                                      width: r.x(20),
                                      height: r.x(20),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: AppColors.white),
                                    )
                                  : Text('ログイン',
                                      style: AppText.noto(r.x(13),
                                          color: AppColors.onBlue,
                                          height: 1.3)),
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
                                      // チェック時は、ログインボタンと同じ青色で塗る。
                                      color: _keep ? AppColors.blue : null,
                                      border: Border.all(
                                          color: _keep
                                              ? AppColors.blue
                                              : AppColors.white,
                                          width: 1.5),
                                      borderRadius:
                                          BorderRadius.circular(r.x(2)),
                                    ),
                                    child: _keep
                                        ? Icon(Icons.check,
                                            size: r.x(16),
                                            color: AppColors.onBlue)
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
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.hint,
    required this.height,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.focusNode,
    this.suffix,
  });

  final String hint;
  final double height;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;

  /// 入力欄の中の右端に置くウィジェット（パスワードの表示/非表示ボタンなど）。
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: keyboardType,
      autocorrect: false,
      enableSuggestions: false,
      // パスワード欄（obscureText）は1行でないと使えないため、1行のまま
      // InputDecoration.constraints で高さを固定する（文字は上下中央に入る）。
      maxLines: 1,
      textAlignVertical: TextAlignVertical.center,
      // iOS Safariは16px未満の入力欄でフォーカス時に拡大するため16px以上にする
      // 入力欄はいつも白い面なので、文字・カーソルは配色に関わらず濃い色（onLight）で固定する。
      cursorColor: AppColors.onLight,
      style: AppText.noto(r.x(13) < 16 ? 16 : r.x(13),
          weight: FontWeight.w400, color: AppColors.onLight, height: 1.3),
      decoration: InputDecoration(
        constraints: BoxConstraints.tightFor(height: height),
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: AppText.noto(r.x(13) < 16 ? 16 : r.x(13),
            weight: FontWeight.w400,
            color: AppColors.onLight.withValues(alpha: 0.5),
            height: 1.3),
        suffixIcon: suffix,
        contentPadding: EdgeInsets.symmetric(horizontal: r.x(14)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.x(6)),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
