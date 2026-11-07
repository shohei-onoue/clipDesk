import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  bool _busy = false;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _showPassword = false;

  /// 入力中に見えたキーボードの高さの最大値。メール欄とパスワード欄で
  /// キーボードの高さが違っても、フォームの位置が変わらないようにそろえる。
  double _keyboardMax = 0;
  bool _showForm = false;
  late final AnimationController _intro;
  final _time = ValueNotifier<double>(0);
  final _hide = ValueNotifier<double>(0);
  late final VideoPlayerController _video;

  /// ログイン認証エラーのときに鳴らす音声（assets/voice.mp3）。
  late final VideoPlayerController _voice;
  bool _voiceReady = false;

  /// ブラウザ（iPhone Safariなど）が自動再生を止めたとき、最初のタップで再生する。
  bool _needsGesture = false;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(_onFocusChange);
    _passwordFocus.addListener(_onFocusChange);
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 18700),
      // 「動きを減らす」ONの端末では、標準だとアニメが約20倍速で終わってしまうため、そのままの速さで流す。
      animationBehavior: AnimationBehavior.preserve,
    )..addListener(() => _time.value = _intro.value * 18.7);
    _video = VideoPlayerController.asset('assets/video_web.mp4');
    _initializeVideo();
    _initializeVoice();
    _intro.forward();
  }

  Future<void> _initializeVideo() async {
    try {
      await _video.initialize();
      await _video.setLooping(true);
      await _video.setVolume(0);
      if (!mounted) return;
      try {
        await _video.play();
      } catch (error) {
        debugPrint('Opening video autoplay blocked: $error');
        _needsGesture = true;
      }
      if (mounted) setState(() {});
    } catch (error) {
      // ローカル動画が読めない場合もログインへ進める。
      debugPrint('Opening video: $error');
      if (mounted) _openForm();
    }
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
    _intro.forward();
  }

  /// メールアドレスとパスワードで Firebase Authentication にログインする。
  Future<void> _login() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('メールアドレスとパスワードを入力してください');
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
    _intro.dispose();
    _time.dispose();
    _hide.dispose();
    _video.dispose();
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
    // フォームをキーボードの上へ持ち上げる（上のREPLAY/SKIPには重ねない）。
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
      backgroundColor: AppColors.loginBg,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          if (_needsGesture) {
            _needsGesture = false;
            _video.play();
          }
        },
        child: Stack(
          children: [
            if (_video.value.isInitialized)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _video.value.size.width,
                    height: _video.value.size.height,
                    child: IgnorePointer(child: VideoPlayer(_video)),
                  ),
                ),
              ),
            Positioned.fill(
              // オープニング中に画面をタップすると、ログインフォームを表示する（SKIPボタンと同じ）。
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!_showForm) _openForm();
                },
                child: CustomPaint(painter: IntroPainter(_time, _hide)),
              ),
            ),
            if (!_showForm)
              Positioned(
                top: r.y(475),
                left: r.x(115),
                width: r.x(160),
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
                      padding: EdgeInsets.zero,
                    ),
                    child: Text('ログインする',
                        maxLines: 1,
                        softWrap: false,
                        style: AppText.noto(r.x(13),
                            color: Colors.white, height: 1.3)),
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
            if (_showForm)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                // キーボードが出ていないときは、タイトルを消す前（オープニング最後の「Clip Desk」の下）と同じ位置。
                top: visibleTop,
                left: r.x(24),
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
                          color: AppColors.hint,
                          icon: Icon(_showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      SizedBox(height: r.y(14)),
                      SizedBox(
                        height: fieldHeight,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _login,
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
                                  // チェック時は、ログインボタンと同じ青色で塗る。
                                  color: _keep ? AppColors.blue : null,
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
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
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pushNamed('/signup'),
                        child: Text('スタッフ新規登録',
                            style: AppText.noto(r.x(12),
                                color: Colors.white,
                                weight: FontWeight.w500,
                                height: 1.3)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
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
      style: AppText.noto(r.x(13) < 16 ? 16 : r.x(13),
          weight: FontWeight.w400, height: 1.3),
      decoration: InputDecoration(
        constraints: BoxConstraints.tightFor(height: height),
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: AppText.noto(r.x(13) < 16 ? 16 : r.x(13),
            weight: FontWeight.w400, color: AppColors.hint, height: 1.3),
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
