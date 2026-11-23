import 'dart:async';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_tts/flutter_tts.dart';

import 'app_settings.dart';

/// 音声読み上げ。設定で「オン」のとき、文字をタップすると、その文字を読み上げる。
/// 読み上げ中に別の文字をタップしたら、前の読み上げを止めて、新しい方を読む。
class ReadAloud {
  ReadAloud._();

  static final ReadAloud instance = ReadAloud._();

  FlutterTts? _tts;

  Future<FlutterTts?> _ready() async {
    if (_tts != null) return _tts;
    try {
      final t = FlutterTts();
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        // iPhone：マナーモードでも鳴らし、読み上げの完了を待てるようにする。
        await t.setSharedInstance(true);
        await t.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      }
      await t.setLanguage('ja-JP');
      _tts = t;
    } catch (_) {}
    return _tts;
  }

  Timer? _later;

  /// スライダーなどで値を動かしている間に使う。最後に動かしてから [wait] 後に読み上げる
  /// （動かしている途中は読まず、止めた位置で1回だけ読む）。
  void speakAfterPause(String text,
      {Duration wait = const Duration(milliseconds: 350)}) {
    _later?.cancel();
    _spokeSinceMove = false;
    _later = Timer(wait, () {
      _spokeSinceMove = true;
      speak(text);
    });
  }

  bool _spokeSinceMove = false;

  /// 予約中の読み上げをやめて、すぐ読み上げる。
  void speakNow(String text) {
    _later?.cancel();
    if (_spokeSinceMove) {
      _spokeSinceMove = false; // 止めている間に読み上げ済み。二度読まない。
      return;
    }
    speak(text);
  }

  Future<void> speak(String text) async {
    final s = text.trim();
    if (s.isEmpty) return;
    try {
      final t = await _ready();
      if (t == null) return;
      await t.stop();
      // 速さの基準が違う：Web（ブラウザ標準）は 1.0 が普通の速さ、Android・iOS は 0.5 が普通。
      final sp = AppSettings.instance.readSpeed;
      await t.setSpeechRate(kIsWeb ? ReadSpeed.webRate(sp) : ReadSpeed.appRate(sp));
      // iPhone：stop 直後の speak が打ち消されることがあるため、少し待つ。
      // Web も、stop（cancel）の直後の speak が無音になることがあるため、少し待つ。
      await Future.delayed(const Duration(milliseconds: 80));
      await t.speak(s);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}
