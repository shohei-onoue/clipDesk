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
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await Future.delayed(const Duration(milliseconds: 80));
      }
      await t.speak(s);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}
