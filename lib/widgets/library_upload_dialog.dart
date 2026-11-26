import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/night_theme.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../data/storage_service.dart';
import 'ruby_text.dart';

/// 端末から完成した動画を1本選ぶ。選ばなければ null。テストで差し替える。
@visibleForTesting
Future<UploadFile?> Function() pickLibraryVideo = () async {
  final f = await FilePicker.pickFile(type: FileType.video);
  return f == null ? null : UploadFile.fromPicked(f);
};

/// ライブラリに完成した動画を追加する入力ダイアログ。追加できたら true。
Future<bool> showLibraryUploadDialog(BuildContext context,
    {required String uid}) async {
  final added = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _LibraryUploadDialog(uid: uid),
  );
  return added ?? false;
}

class _LibraryUploadDialog extends StatefulWidget {
  const _LibraryUploadDialog({required this.uid});
  final String uid;

  @override
  State<_LibraryUploadDialog> createState() => _LibraryUploadDialogState();
}

class _LibraryUploadDialogState extends State<_LibraryUploadDialog> {
  /// 失敗して押し直しても、追加は1件になるよう、最初に1回だけ採番する。
  late final _requestId = Services.repo.newRequestId();
  final _title = TextEditingController();
  final _poster = TextEditingController();

  /// アップロード日時。変えなければ、開いた時刻ではなく、押した時刻にする。
  DateTime? _uploadedAt;
  final _openedAt = DateTime.now();
  UploadFile? _file;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fillPoster();
  }

  /// 投稿者名は、自分の名前を入れておく（直せる）。
  Future<void> _fillPoster() async {
    final name = await Services.repo.displayName(widget.uid);
    if (!mounted || name == null || _poster.text.isNotEmpty) return;
    _poster.text = name;
  }

  @override
  void dispose() {
    _title.dispose();
    _poster.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final file = await pickLibraryVideo();
      if (!mounted || file == null) return;
      setState(() {
        _error = null;
        if (!isVideoFileName(file.name)) {
          _error = 'エラー：動画ではありません。mp4・mov・m4v・webm の動画を選んでください';
        } else if (file.size > kMaxFileBytes) {
          _error = 'エラー：ファイルが大きすぎます。'
              '${kMaxFileBytes ~/ 1024 ~/ 1024}MBまでの動画を選んでください';
        } else {
          _file = file;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'エラー：動画を選べませんでした（$e）。もう一度お試しください');
      }
    }
  }

  Future<void> _pickDate() async {
    final current = _uploadedAt ?? _openedAt;
    Widget themed(BuildContext context, Widget? child) {
      final base = nightTheme;
      return Theme(
        // 背景は透けない単色（ink）にする。
        data: base.copyWith(
          colorScheme: base.colorScheme.copyWith(surface: AppColors.ink),
          datePickerTheme: DatePickerThemeData(backgroundColor: AppColors.ink),
          timePickerTheme: TimePickerThemeData(backgroundColor: AppColors.ink),
        ),
        child: child!,
      );
    }

    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: themed,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: themed,
    );
    if (time == null || !mounted) return;
    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final now = DateTime.now();
    // 今より先の時刻は、今にする。
    setState(() => _uploadedAt = picked.isAfter(now) ? now : picked);
  }

  Future<void> _submit() async {
    final file = _file;
    final missing = file == null
        ? '動画が選ばれていません。動画を選んでください'
        : _title.text.trim().isEmpty
            ? '動画タイトルが未入力です。入力してください'
            : _poster.text.trim().isEmpty
                ? '投稿者名が未入力です。入力してください'
                : null;
    if (file == null || missing != null) {
      setState(() => _error = 'エラー：$missing');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Services.repo.addLibraryVideo(
        requestId: _requestId,
        uid: widget.uid,
        title: _title.text,
        posterName: _poster.text,
        uploadedAt: _uploadedAt ?? DateTime.now(),
        file: file,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'エラー：アップロードできませんでした（$e）。通信を確認して、もう一度お試しください';
        });
      }
    }
  }

  static String _dateTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}/${two(t.month)}/${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    // 入力欄の間隔。文字が大きいときは、枠の上の見出しが重ならないよう広げる。
    final fieldGap = r.large ? r.tx(12) : r.y(12);
    final note = AppText.dark(14,
        weight: FontWeight.w400,
        color: AppColors.white.withValues(alpha: 0.7),
        height: 1.5);
    final outlined = OutlinedButton.styleFrom(
      foregroundColor: AppColors.white,
      side: BorderSide(color: AppColors.white.withValues(alpha: 0.55)),
      minimumSize: const Size(96, 44),
    );
    return PopScope(
      // アップロード中は、閉じられないようにする。
      canPop: !_busy,
      child: Theme(
        data: nightTheme,
        child: AlertDialog(
          insetPadding: r.large
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
              : null,
          backgroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(
              side: BorderSide(color: AppColors.white.withValues(alpha: 0.16)),
              borderRadius: BorderRadius.circular(r.x(15))),
          title: Text('完成した動画を追加', style: AppText.dark(16)),
          // 文字が大きく画面が低いときも、ボタンまで操作できるようにする。
          scrollable: true,
          content: SizedBox(
            width: r.x(340),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pick,
                  style: outlined,
                  icon: const Icon(Icons.video_file_outlined),
                  label: Text(_file == null ? '動画を選ぶ' : '動画を選び直す'),
                ),
                SizedBox(height: r.y(4)),
                Text(_file?.name ?? '動画は選ばれていません',
                    ruby: _file == null, style: note),
                SizedBox(height: fieldGap + r.y(4)),
                TextField(
                  controller: _title,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                      labelText: '動画タイトル', border: OutlineInputBorder()),
                ),
                SizedBox(height: fieldGap),
                TextField(
                  controller: _poster,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                      labelText: '投稿者名', border: OutlineInputBorder()),
                ),
                SizedBox(height: fieldGap),
                Text('アップロード日時', style: note),
                SizedBox(height: r.y(4)),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickDate,
                  style: outlined,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_dateTime(_uploadedAt ?? _openedAt),
                      semanticsLabel:
                          'アップロード日時を変更する ${_dateTime(_uploadedAt ?? _openedAt)}'),
                ),
                if (_busy) ...[
                  SizedBox(height: r.y(16)),
                  const LinearProgressIndicator(),
                  SizedBox(height: r.y(8)),
                  Text('アップロードしています。画面を閉じずにお待ちください。', style: note),
                ],
                if (_error != null) ...[
                  SizedBox(height: r.y(12)),
                  Text(_error!,
                      style: AppText.dark(13,
                          weight: FontWeight.w400, color: AppColors.amber)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.white,
                  minimumSize: const Size(64, 44)),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: AppColors.on(AppColors.blue),
                  minimumSize: const Size(96, 44)),
              child: const Text('アップロード'),
            ),
          ],
        ),
      ),
    );
  }
}
