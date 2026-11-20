import 'package:flutter/material.dart' hide Text;
import 'package:speech_to_text/speech_to_text.dart';

import '../core/japanese_speech.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_tokens.dart';
import 'ruby_text.dart';

/// メッセージ入力のダイアログ。キーボード入力に加えて、マイクで音声入力できる。
/// 送信なら入力した文字（前後の空白なし）、キャンセルなら null を返す。
Future<String?> showVoiceMessageDialog(
  BuildContext context, {
  required String title,
  required String hint,
  String sendLabel = '送信',
  String initialText = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _VoiceMessageDialog(
        title: title,
        hint: hint,
        sendLabel: sendLabel,
        initialText: initialText),
  );
}

class _VoiceMessageDialog extends StatefulWidget {
  const _VoiceMessageDialog(
      {required this.title,
      required this.hint,
      required this.sendLabel,
      this.initialText = ''});
  final String title;
  final String hint;
  final String sendLabel;
  final String initialText;

  @override
  State<_VoiceMessageDialog> createState() => _VoiceMessageDialogState();
}

class _VoiceMessageDialogState extends State<_VoiceMessageDialog> {
  late final _text = TextEditingController(text: widget.initialText);
  final _speech = SpeechToText();
  bool _ready = false;

  /// 端末の音声認識が持つ日本語のロケールID。
  String? _localeId;
  bool _listening = false;
  String? _notice;

  /// 音声入力を始める前に入っていた文字。認識結果はこの後ろにつなげる。
  String _base = '';

  @override
  void dispose() {
    _speech.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_ready) {
      _ready = await _speech.initialize(
        onStatus: (s) {
          if (mounted && (s == 'done' || s == 'notListening')) {
            setState(() => _listening = false);
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _listening = false;
              _notice = 'エラー：音声を聞き取れませんでした。もう一度マイクを押してください';
            });
          }
        },
      );
    }
    if (!_ready) {
      if (mounted) {
        setState(() =>
            _notice = 'エラー：このブラウザ・端末では音声入力が使えません。マイクの許可を確認するか、文字で入力してください');
      }
      return;
    }
    // 日本語で聞き取る。端末が報告する日本語のロケールIDがあればそれを使う（なければ ja_JP）。
    _localeId ??= await findJapaneseLocale(_speech);
    _base = _text.text.trim();
    setState(() {
      _listening = true;
      _notice = null;
    });
    await _speech.listen(
      listenOptions:
          SpeechListenOptions(partialResults: true, localeId: _localeId),
      onResult: (r) {
        final spoken = r.recognizedWords;
        final joined = _base.isEmpty ? spoken : '$_base $spoken';
        _text.value = TextEditingValue(
          text: joined,
          selection: TextSelection.collapsed(offset: joined.length),
        );
      },
    );
  }

  /// 入力した内容（音声の認識結果も）を消して、最初から入力し直す。聞き取り中なら止める。
  Future<void> _redo() async {
    if (_listening) await _speech.cancel();
    _base = '';
    _text.clear();
    if (mounted) {
      setState(() {
        _listening = false;
        _notice = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    return AlertDialog(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.white.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text(widget.title, style: AppText.dark(18)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [
              TextField(
                controller: _text,
                autofocus: true,
                minLines: 4,
                maxLines: 6,
                style: AppText.dark(15, weight: FontWeight.w400, height: 1.5),
                cursorColor: AppColors.white,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: AppText.dark(15,
                      weight: FontWeight.w400,
                      color: AppColors.white.withValues(alpha: 0.7)),
                  contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 46),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: radius,
                      borderSide: BorderSide(
                          color: AppColors.white.withValues(alpha: 0.55))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: radius,
                      borderSide: BorderSide(color: AppColors.white)),
                ),
              ),
              // 聞き間違いのとき、入力を消して最初からやり直す。入力欄の右下の最前面。
              Positioned(
                right: 8,
                bottom: 8,
                child: TextButton.icon(
                  onPressed: _redo,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('やり直し'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.white,
                    backgroundColor: AppColors.bg.withValues(alpha: 0.85),
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ]),
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_notice!,
                    style: AppText.dark(12,
                        weight: FontWeight.w400, color: AppColors.amber)),
              ),
          ],
        ),
      ),
      // マイクは「キャンセル」「送信」と同じ行の左端。
      actionsAlignment: MainAxisAlignment.start,
      actions: [
        IconButton.filled(
          tooltip: _listening ? '音声入力をとめる' : '音声で入力する',
          style: IconButton.styleFrom(
            backgroundColor: _listening ? AppColors.amber : AppColors.blue,
            foregroundColor: _listening ? AppColors.onAmber : AppColors.onBlue,
            minimumSize: const Size(44, 44),
          ),
          onPressed: _toggle,
          icon: Icon(_listening ? Icons.stop : Icons.mic),
        ),
        const SizedBox(width: 24),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.white,
            side: BorderSide(color: AppColors.white.withValues(alpha: 0.55)),
            minimumSize: const Size(96, 44),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _text.text.trim()),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.blue,
            foregroundColor: AppColors.onBlue,
            minimumSize: const Size(96, 44),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          child: Text(widget.sendLabel),
        ),
      ],
    );
  }
}
