import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/app_colors.dart';
import '../core/japanese_speech.dart';

/// 入力欄（[TextEditingController]）へ、マイクの音声を日本語で書き込む。
/// 聞き取り中・エラーの状態は [ChangeNotifier] で伝える。
class VoiceInput extends ChangeNotifier {
  final _speech = SpeechToText();
  bool _ready = false;
  bool _disposed = false;
  String? _localeId;

  /// 音声入力を始める前に入っていた文字。認識結果はこの後ろにつなげる。
  String _base = '';

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
  Future<void> toggle(TextEditingController controller) async {
    if (listening) {
      await _speech.stop();
      _update(listening: false);
      return;
    }
    if (!_ready) {
      _ready = await _speech.initialize(
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') _update(listening: false);
        },
        onError: (e) => _update(
            listening: false, notice: 'エラー：音声を聞き取れませんでした。もう一度マイクを押してください'),
      );
    }
    if (!_ready) {
      _update(notice: 'エラー：このブラウザ・端末では音声入力が使えません。マイクの許可を確認するか、文字で入力してください');
      return;
    }
    // 日本語で聞き取る。端末が報告する日本語のロケールIDがあればそれを使う（なければ ja_JP）。
    _localeId ??= await findJapaneseLocale(_speech);
    _base = controller.text.trim();
    final session = ++_session;
    _update(listening: true, clearNotice: true);
    await _speech.listen(
      listenOptions:
          SpeechListenOptions(partialResults: true, localeId: _localeId),
      onResult: (r) {
        if (session != _session) return;
        final joined =
            _base.isEmpty ? r.recognizedWords : '$_base ${r.recognizedWords}';
        controller.value = TextEditingValue(
            text: joined,
            selection: TextSelection.collapsed(offset: joined.length));
      },
    );
  }

  /// 聞き取りを捨てる。止めたあとに遅れて届く認識結果は、入力欄へ書き込まない
  /// （送信して入力欄を空にしたあとに、前の回答が戻らないようにする）。
  Future<void> cancel() async {
    _session++;
    await _speech.cancel();
    _update(listening: false);
  }

  /// 聞き取り中なら止める。
  Future<void> stop() async {
    if (!listening) return;
    await _speech.stop();
    _update(listening: false);
  }

  @override
  void dispose() {
    _disposed = true;
    _speech.cancel();
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
              ? AppColors.onAmber
              : AppColors.white.withValues(alpha: enabled ? 0.7 : 0.3)),
    );
  }
}

/// 音声入力中、画面の中心に大きなマイクを出す（操作は通す）。Stack の上に重ねて使う。
class VoiceListeningOverlay extends StatelessWidget {
  const VoiceListeningOverlay({super.key, required this.listening});
  final bool listening;

  @override
  Widget build(BuildContext context) {
    if (!listening) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.blue.withValues(alpha: 0.85),
            ),
            child: Icon(Icons.mic, size: 96, color: AppColors.onBlue),
          ),
        ),
      ),
    );
  }
}
