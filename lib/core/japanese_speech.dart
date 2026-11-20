import 'package:speech_to_text/speech_to_text.dart';

const fallbackJapaneseLocale = 'ja_JP';

/// 音声認識に渡す日本語のロケールID。端末が報告する一覧に日本語があればそのID（'ja_JP'・'ja-JP' など）、
/// 一覧が取れない・日本語が載っていないときは 'ja_JP'（以前と同じ）。必ず値を返し、音声入力を止めない。
///
/// Android では、ロケールIDを固定の文字列で渡すと日本語として扱われず、英語で聞き取ってしまう
/// ことがある。そのため、端末が報告するロケールの一覧から日本語のものを選んで、そのIDをそのまま使う。
/// [initialize] のあとに呼ぶ。
Future<String> findJapaneseLocale(SpeechToText speech) async {
  try {
    final locales = await speech.locales();
    // 'ja_JP' と 'ja-JP' のどちらの書き方でも拾う。日本（JP）を優先する。
    final ja = [
      for (final l in locales)
        if (l.localeId.toLowerCase().replaceAll('-', '_').startsWith('ja')) l
    ];
    if (ja.isEmpty) return fallbackJapaneseLocale;
    final jp = ja
        .where((l) => l.localeId.toLowerCase().replaceAll('-', '_') == 'ja_jp');
    return (jp.isNotEmpty ? jp.first : ja.first).localeId;
  } catch (_) {
    return fallbackJapaneseLocale;
  }
}
