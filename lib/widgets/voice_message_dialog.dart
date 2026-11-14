import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_tokens.dart';

/// メッセージ入力のダイアログ。キーボード入力に加えて、マイクで音声入力できる。
/// 送信なら入力した文字（前後の空白なし）、キャンセルなら null を返す。
Future<String?> showVoiceMessageDialog(
  BuildContext context, {
  required String title,
  required String hint,
  String sendLabel = '送信',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _VoiceMessageDialog(title: title, hint: hint, sendLabel: sendLabel),
  );
}

class _VoiceMessageDialog extends StatefulWidget {
  const _VoiceMessageDialog(
      {required this.title, required this.hint, required this.sendLabel});
  final String title;
  final String hint;
  final String sendLabel;

  @override
  State<_VoiceMessageDialog> createState() => _VoiceMessageDialogState();
}

class _VoiceMessageDialogState extends State<_VoiceMessageDialog> {
  final _text = TextEditingController();
  final _speech = SpeechToText();
  bool _ready = false;
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
    _base = _text.text.trim();
    setState(() {
      _listening = true;
      _notice = null;
    });
    await _speech.listen(
      listenOptions:
          SpeechListenOptions(partialResults: true, localeId: 'ja_JP'),
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

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    return AlertDialog(
      backgroundColor: AppColors.ink,
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
                contentPadding: const EdgeInsets.all(12),
                enabledBorder: OutlineInputBorder(
                    borderRadius: radius,
                    borderSide: BorderSide(
                        color: AppColors.white.withValues(alpha: 0.55))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: radius,
                    borderSide: const BorderSide(color: AppColors.white)),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              IconButton.filled(
                tooltip: _listening ? '音声入力をとめる' : '音声で入力する',
                style: IconButton.styleFrom(
                  backgroundColor:
                      _listening ? AppColors.amber : AppColors.blue,
                  foregroundColor: _listening ? AppColors.ink : AppColors.white,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: _toggle,
                icon: Icon(_listening ? Icons.stop : Icons.mic),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _listening ? '聞き取り中です。話し終えたら止めてください' : 'マイクを押すと、話した内容が入力されます',
                  style: AppText.dark(12,
                      weight: FontWeight.w400,
                      color: AppColors.white.withValues(alpha: 0.7),
                      height: 1.4),
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
      actions: [
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
            foregroundColor: AppColors.white,
            minimumSize: const Size(96, 44),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          child: Text(widget.sendLabel),
        ),
      ],
    );
  }
}
