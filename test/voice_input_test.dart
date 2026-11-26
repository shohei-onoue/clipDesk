import 'package:clipdesk/widgets/voice_input.dart';
import 'package:clipdesk/widgets/voice_message_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 端末の音声認識の代わり。合図や結果は、テストから送る。
class _FakeSpeech extends Fake implements SpeechToText {
  @override
  SpeechStatusListener? statusListener;
  @override
  SpeechErrorListener? errorListener;

  SpeechResultListener? onResult;
  bool failListen = false;
  int stops = 0;
  int cancels = 0;

  @override
  Future<bool> initialize(
          {SpeechErrorListener? onError,
          SpeechStatusListener? onStatus,
          debugLogging = false,
          Duration finalTimeout = SpeechToText.defaultFinalTimeout,
          List<SpeechConfigOption>? options}) async =>
      true;

  @override
  Future listen(
      {SpeechResultListener? onResult,
      Duration? listenFor,
      Duration? pauseFor,
      String? localeId,
      SpeechSoundLevelChange? onSoundLevelChange,
      cancelOnError = false,
      partialResults = true,
      onDevice = false,
      ListenMode listenMode = ListenMode.confirmation,
      sampleRate = 0,
      SpeechListenOptions? listenOptions}) async {
    if (failListen) throw StateError('already started');
    this.onResult = onResult;
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> cancel() async => cancels++;

  void say(String words) => onResult!(SpeechRecognitionResult.init(
      [SpeechRecognitionWords(words, null, 1)], ResultType.partial));
}

void main() {
  late _FakeSpeech speech;

  setUp(() => speech = _FakeSpeech());

  testWidgets('認識から終了の合図がなくても、無音が続けば聞き取りを終える', (tester) async {
    final voice = VoiceInput(speech: speech);
    final text = TextEditingController(text: '前の文');
    await voice.start(text);
    expect(voice.listening, isTrue);

    speech.say('こんにちは');
    expect(text.text, '前の文 こんにちは');

    await tester.pump(VoiceInput.silence + const Duration(milliseconds: 100));
    expect(voice.listening, isFalse);
    expect(speech.stops, 1);
    expect(voice.notice, isNull);
    voice.dispose();
  });

  testWidgets('何も聞こえないまま時間がたつと、終えて知らせる', (tester) async {
    final voice = VoiceInput(speech: speech);
    await voice.start(TextEditingController());
    // iPhone では、始まった合図だけ届いて、その後が来ないことがある。
    speech.statusListener!(SpeechToText.listeningStatus);

    await tester.pump(VoiceInput.startWait + const Duration(milliseconds: 100));
    expect(voice.listening, isFalse);
    expect(voice.notice, voiceSilentNotice);
    voice.dispose();
  });

  testWidgets('話し続けても、上限の時間で終える', (tester) async {
    final voice = VoiceInput(speech: speech);
    await voice.start(TextEditingController());
    for (var i = 0; i < 20; i++) {
      speech.onResult == null ? null : speech.say('あ' * (i + 1));
      await tester.pump(const Duration(seconds: 4));
    }
    expect(voice.listening, isFalse);
    voice.dispose();
  });

  testWidgets('2つ目の入力欄でも、終了の合図が届く', (tester) async {
    final first = VoiceInput(speech: speech);
    await first.start(TextEditingController());
    await first.stop();
    first.dispose();

    final second = VoiceInput(speech: speech);
    await second.start(TextEditingController());
    speech.statusListener!(SpeechToText.listeningStatus);
    speech.statusListener!(SpeechToText.doneStatus);
    expect(second.listening, isFalse);
    second.dispose();
  });

  testWidgets('開始に失敗しても、聞き取り中のままにしない', (tester) async {
    speech.failListen = true;
    final voice = VoiceInput(speech: speech);
    await voice.start(TextEditingController());
    expect(voice.listening, isFalse);
    expect(voice.notice, voiceFailedNotice);

    // もう一度押せば、始められる。
    speech.failListen = false;
    await voice.start(TextEditingController());
    expect(voice.listening, isTrue);
    voice.dispose();
  });

  testWidgets('マイクが許可されていないときは、次の操作を知らせる', (tester) async {
    final voice = VoiceInput(speech: speech);
    await voice.start(TextEditingController());
    speech.errorListener!(SpeechRecognitionError('not-allowed', false));
    expect(voice.listening, isFalse);
    expect(voice.notice, contains('マイクが許可されていません'));
    voice.dispose();
  });

  testWidgets('止めたあとに直した文字は、遅れて届く結果で上書きしない', (tester) async {
    final voice = VoiceInput(speech: speech);
    final text = TextEditingController();
    await voice.start(text);
    speech.say('明日');
    await voice.stop();
    speech.say('明日まで');
    expect(text.text, '明日まで', reason: '直していなければ、最後の結果は反映する');

    text.text = '来週まで';
    speech.say('明日までに');
    expect(text.text, '来週まで');

    await voice.cancel();
    speech.say('古い結果');
    expect(text.text, '来週まで');
    voice.dispose();
  });

  testWidgets('入力ダイアログは、文字「大」でキーボードが出てもはみ出さない', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => showVoiceMessageDialog(context,
                    title: 'その他の指示', hint: 'その他の指示を入力（音声でも入力できます）'),
                child: const Text('開く')))));
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('送信'));
    await tester.pumpAndSettle();
    expect(find.text('送信').hitTestable(), findsOneWidget);
  });

  testWidgets('聞き取り中の大きなマイクを押すと止まる', (tester) async {
    final voice = VoiceInput(speech: speech);
    await tester.pumpWidget(MaterialApp(
        home: ListenableBuilder(
            listenable: voice,
            builder: (_, __) =>
                Stack(children: [VoiceListeningOverlay(voice: voice)]))));
    await voice.start(TextEditingController());
    await tester.pump();
    await tester.tap(find.text('押すと止まります'));
    await tester.pump();
    expect(voice.listening, isFalse);
    expect(find.text('押すと止まります'), findsNothing);
    voice.dispose();
  });
}
