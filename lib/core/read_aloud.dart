import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

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
      await t.setLanguage('ja-JP');
      // 速さの基準が違う：Web（ブラウザ標準）は 1.0 が普通の速さ、Android・iOS は 0.5 が普通。普通より少し速くする。
      await t.setSpeechRate(kIsWeb ? 1.25 : 0.55);
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
      await t.speak(s);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}
