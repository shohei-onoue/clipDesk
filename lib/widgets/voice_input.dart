import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/app_colors.dart';
import '../core/japanese_speech.dart';
import '../core/part_colors.dart';
import '../core/read_aloud.dart';

const voiceUnavailableNotice =
    'エラー：このブラウザ・端末では音声入力が使えません。マイクの許可を確認するか、文字で入力してください';
const voiceFailedNotice = 'エラー：音声を聞き取れませんでした。もう一度マイクを押してください';
const voiceSilentNotice = 'エラー：音声が聞こえませんでした。もう一度マイクを押してください';

/// 音声認識のエラーの種類に合った、次の操作の案内。
String voiceErrorNotice(String code) => switch (code) {
      'not-allowed' ||
      'error_permission' =>
        'エラー：マイクが許可されていません。端末の設定でマイクを許可するか、文字で入力してください',
      'service-not-allowed' =>
        'エラー：端末の音声入力が使えません。iPhone は「設定」で Siri と音声入力をオンにするか、文字で入力してください',
      _ => voiceFailedNotice,
    };

/// 入力欄（[TextEditingController]）へ、マイクの音声を日本語で書き込む。
/// 聞き取り中・エラーの状態は [ChangeNotifier] で伝える。
///
/// iPhone の Safari では、音声認識が「終わった」の合図を返さないことがある。
/// 合図を待つと聞き取り中のまま固まるため、無音の時間と全体の時間を自分で計って終える。
class VoiceInput extends ChangeNotifier {
  VoiceInput({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  /// 話し始めを待つ時間。
  static const startWait = Duration(seconds: 10);

  /// 話し終わってから、聞き取りを終えるまでの時間。
  static const silence = Duration(seconds: 5);

  /// 1回の聞き取りの上限。
  static const maxListen = Duration(seconds: 60);

  /// いま音声認識を使っている入力欄。認識の機能はアプリで1つだけなので、同時には使えない。
  static VoiceInput? _active;

  final SpeechToText _speech;
  bool _disposed = false;
  bool _starting = false;
  String? _localeId;
  Timer? _silenceTimer;
  Timer? _maxTimer;

  /// 今回の聞き取りで、認識が始まった合図か結果が届いたか。
  bool _heard = false;

  /// 聞き取りの世代。cancel / 新規開始で増やし、古い認識結果が入力欄へ書き込まれないようにする。
  int _session = 0;

  bool listening = false;
  String? notice;

  void _update({bool? listening, String? notice, bool clearNotice = false}) {
    if (_disposed) return;
    if (listening != null) this.listening = listening;
    if (clearNotice) {
      this.notice = null;
    } else if (notice != null) {
      this.notice = notice;
    }
    notifyListeners();
  }

  /// 聞き取り中なら止め、止まっていれば始める。
  Future<void> toggle(TextEditingController controller) =>
      listening ? stop() : start(controller);

  Future<void> start(TextEditingController controller) async {
    if (_disposed || _starting || listening) return;
    _starting = true;
    final session = ++_session;
    // キーボードは閉じる。読み上げ中なら止める（音声がマイクに入らないように）。
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(ReadAloud.instance.stop());
    try {
      final other = _active;
      if (other != null && other != this) await other.cancel();
      final ready = await _speech.initialize();
      if (_disposed || session != _session) return;
      if (!ready) {
        _update(notice: voiceUnavailableNotice);
        return;
      }
      // 認識の機能はアプリで共有していて、initialize で渡した受け取り先は最初の1回しか
      // 登録されない。毎回、今の入力欄を受け取り先にする。
      _speech.statusListener = (s) => _onStatus(session, s);
      _speech.errorListener = (e) => _onError(session, e);
      // ブラウザは 'ja-JP' の書き方。端末のアプリは、端末が報告する日本語のロケールIDを使う。
      final locale =
          kIsWeb ? 'ja-JP' : _localeId ??= await findJapaneseLocale(_speech);
      if (_disposed || session != _session) return;
      _active = this;
      _heard = false;
      final base = controller.text.trim();
      var written = controller.text;
      _update(listening: true, clearNotice: true);
      _maxTimer = Timer(maxListen, stop);
      _arm(startWait);
      // ここから先はマイクのボタンが「とめる」になる。開始の返事が来なくても押せるようにする。
      _starting = false;
      await _speech.listen(
        listenOptions:
            SpeechListenOptions(partialResults: true, localeId: locale),
        onResult: (r) {
          if (session != _session) return;
          // 止めたあとに届く結果は、利用者が入力欄を直していたら書き込まない。
          if (!listening && controller.text != written) return;
          _heard = true;
          final spoken = r.recognizedWords;
          written = base.isEmpty ? spoken : '$base $spoken';
          controller.value = TextEditingValue(
              text: written,
              selection: TextSelection.collapsed(offset: written.length));
          if (listening) _arm(silence);
        },
      );
    } catch (e) {
      debugPrint('音声入力を始められませんでした：$e');
      if (session == _session) {
        _finish();
        _update(notice: voiceFailedNotice);
        unawaited(_quietly(_speech.cancel));
      }
    } finally {
      _starting = false;
    }
  }

  /// [wait] の間、新しい結果が届かなければ、聞き取りを終える。
  void _arm(Duration wait) {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(wait, () {
      stop();
      // 話し始めを待つ間に何も届かなければ、聞こえなかったことを知らせる。
      if (wait == startWait) _update(notice: voiceSilentNotice);
    });
  }

  void _onStatus(int session, String status) {
    if (session != _session) return;
    if (status == SpeechToText.listeningStatus) {
      _heard = true;
    } else if (_heard && listening) {
      // 前の聞き取りの終了の合図が遅れて届いても、始まる前なら無視する。
      _finish();
    }
  }

  void _onError(int session, SpeechRecognitionError error) {
    if (session != _session || !listening || error.errorMsg == 'aborted') {
      return;
    }
    _finish();
    _update(notice: voiceErrorNotice(error.errorMsg));
  }

  /// 画面の「聞き取り中」を終える。認識の機能の返事は待たない。
  void _finish() {
    _silenceTimer?.cancel();
    _maxTimer?.cancel();
    if (listening) _update(listening: false);
  }

  Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('音声入力を終えられませんでした：$e');
    }
  }

  /// 聞き取りを捨てる。止めたあとに遅れて届く認識結果は、入力欄へ書き込まない
  /// （送信して入力欄を空にしたあとに、前の回答が戻らないようにする）。
  Future<void> cancel() async {
    _session++;
    final mine = _active == this;
    if (mine) _active = null;
    _finish();
    _update(clearNotice: true);
    if (mine) await _quietly(_speech.cancel);
  }

  /// 聞き取り中なら止める。ここまでの認識結果は入力欄に残す。
  Future<void> stop() async {
    if (!listening) return;
    _finish();
    await _quietly(_speech.stop);
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(cancel());
    super.dispose();
  }
}

/// 入力欄の左に置くマイクボタン。聞き取り中は琥珀色の停止アイコンになる。
/// [onPressed] が null のときは押せない（グレー）。
class VoiceMicButton extends StatelessWidget {
  const VoiceMicButton(
      {super.key,
      required this.voice,
      required this.controller,
      this.enabled = true});

  final VoiceInput voice;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final on = voice.listening;
    return IconButton(
      tooltip: on ? '音声入力をとめる' : '音声で入力する',
      onPressed: enabled || on ? () => voice.toggle(controller) : null,
      style: IconButton.styleFrom(
          backgroundColor: on ? AppColors.amber : Colors.transparent),
      icon: Icon(on ? Icons.stop : Icons.mic,
          size: 28,
          color: on
              ? PartColors.onAmber
              : AppColors.white.withValues(alpha: enabled ? 0.7 : 0.3)),
    );
  }
}

/// 音声入力中、画面の中心に大きなマイクを出す。Stack の上に重ねて使う。
/// マイクを押すと聞き取りを止める。マイクの外側の操作は、下の画面に通す。
class VoiceListeningOverlay extends StatelessWidget {
  const VoiceListeningOverlay({super.key, required this.voice});
  final VoiceInput voice;

  @override
  Widget build(BuildContext context) {
    if (!voice.listening) return const SizedBox.shrink();
    final color = AppColors.on(AppColors.blue);
    return Positioned.fill(
      child: Center(
        child: Semantics(
          button: true,
          label: '音声入力をとめる',
          child: GestureDetector(
            onTap: voice.stop,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.blue.withValues(alpha: 0.85),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic, size: 80, color: color),
                  // 円の大きさは固定なので、文字の大きさの設定は掛けない。
                  Text('押すと止まります',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                          fontFamily: 'NotoSansJP',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
