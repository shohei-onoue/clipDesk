import 'package:flutter/material.dart' hide Text;

import '../core/app_colors.dart';
import '../core/part_colors.dart';
import '../core/app_text.dart';
import '../core/app_tokens.dart';
import '../core/web_platform.dart';
import 'ruby_text.dart';
import 'voice_input.dart';

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

  /// 音声入力。指示作成の画面などと同じ部品を使う。
  final _voice = VoiceInput();

  @override
  void initState() {
    super.initState();
    _voice.addListener(_onVoice);
  }

  void _onVoice() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _voice.removeListener(_onVoice);
    _voice.dispose();
    _text.dispose();
    super.dispose();
  }

  /// 入力した内容（音声の認識結果も）を消して、最初から入力し直す。聞き取り中なら止める。
  Future<void> _redo() async {
    final cancel = _voice.cancel();
    _text.clear();
    await cancel;
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    final listening = _voice.listening;
    final notice = _voice.notice;
    return AlertDialog(
      // キーボードが出て高さが足りないときは、スクロールできるようにする。
      scrollable: true,
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
            Stack(children: [
              TextField(
                controller: _text,
                // スマートフォンのブラウザでは、自動でフォーカスするとキーボードが出なくなるため、
                // 利用者が入力欄をタップしてから入力する。
                autofocus: !isMobileWeb,
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
                    backgroundColor: AppColors.ink.withValues(alpha: 0.85),
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ]),
            if (notice != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(notice,
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
          tooltip: listening ? '音声入力をとめる' : '音声で入力する',
          style: IconButton.styleFrom(
            backgroundColor: listening ? AppColors.amber : AppColors.blue,
            foregroundColor:
                listening ? PartColors.onAmber : AppColors.on(AppColors.blue),
            minimumSize: const Size(44, 44),
          ),
          onPressed: () => _voice.toggle(_text),
          icon: Icon(listening ? Icons.stop : Icons.mic),
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
            foregroundColor: AppColors.on(AppColors.blue),
            minimumSize: const Size(96, 44),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          child: Text(widget.sendLabel),
        ),
      ],
    );
  }
}
