import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_tokens.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../data/storage_service.dart';
import '../domain/draft.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/status_style.dart';
import '../widgets/app_icon.dart';

enum _Step {
  title,
  videoType,
  platform,
  purpose,
  length,
  orientation,
  subtitle,
  video,
  due,
  review,
}

class _Msg {
  const _Msg(this.mine, this.text, {this.step});
  final bool mine;
  final String text;

  /// ユーザーの回答のとき、どの質問への回答か。タップすると選び直せる。
  final _Step? step;
}

/// 03 チャットで依頼を作成する。質問は固定の流れ（AIによる生成は使わない）で、
/// 入力・選択した内容がそのまま指示書（目的・構成・納品条件・場面別指示）になる。
/// 要確認の再送信時は、引数の [RequestDraft] から開始して指示書を修正する。
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _msgs = <_Msg>[];
  RequestDraft? _draft;
  _Step _step = _Step.title;
  bool _picking = false;

  /// 「その他」「直接入力」を選んだあと、自由入力を待っている間は true。
  bool _awaitText = false;

  /// 納品条件（長さ・向き・字幕）を組み立てる途中の値。
  String _length = '';
  String _orientation = '';
  String _subtitle = '';

  /// 確認画面から戻って1項目だけ直している間は、直し終えたら review に戻る。
  bool _fixing = false;

  final _scroll = ScrollController();

  /// 最新のナビゲーターの発言（連続していれば最初の1つ）のバブル。これを画面の上端に出す。
  final _latestKey = GlobalKey();
  int _shownCount = 0;

  /// 質問が増えたら、最新の質問が画面トップに来るようスクロールする。
  void _scrollToLatestQuestion() {
    if (_msgs.length == _shownCount) return;
    _shownCount = _msgs.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _latestKey.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(ctx,
          alignment: 0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut);
    });
  }

  RequestDraft get d => _draft!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draft != null) return;
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is RequestDraft) {
      _draft = arg;
      final reason = arg.original?.reviewReason;
      _say(arg.original == null
          ? '入力済みの内容を確認・修正できます。'
          : '編集者から確認がありました。内容を直して再送信してください。${reason == null ? '' : '\n確認事項：$reason'}');
      _enterReview();
    } else {
      _draft = RequestDraft(requestId: Services.repo.newRequestId());
      _say('こんにちは。いくつか質問に答えるだけで、編集者への指示書ができます。');
      _say('依頼名（動画のタイトル）を入力してください。');
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _say(String t) => _msgs.add(_Msg(false, t));
  void _me(String t, {_Step? step}) => _msgs.add(_Msg(true, t, step: step));

  void _enterReview() {
    _step = _Step.review;
    _fixing = false;
  }

  void _prompt(_Step s) {
    _step = s;
    _say(switch (s) {
      _Step.title => '依頼名（動画のタイトル）を入力してください。',
      _Step.videoType => 'どんな動画ですか？',
      _Step.platform => 'どこに投稿しますか？',
      _Step.purpose => '動画の目的を教えてください。',
      _Step.length => '動画の長さを選んでください。',
      _Step.orientation => '画面の向きを選んでください。',
      _Step.subtitle => '字幕は必要ですか？',
      _Step.video => '動画・画像を添付してください。複数追加できます。入力欄の左のクリップから追加してください。',
      _Step.due => '希望納期を選んでください。',
      _Step.review => '内容を確認してください。',
    });
  }

  /// 1項目の回答後、次の質問（または確認）へ進む。
  void _next(_Step after) {
    if (_fixing) {
      _enterReview();
      _say('直しました。他に直す所がなければ「指示内容を確認する」を押してください。');
    } else {
      _prompt(after);
    }
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final handled = switch (_step) {
      _Step.videoType ||
      _Step.platform ||
      _Step.title ||
      _Step.purpose ||
      _Step.length ||
      _Step.orientation ||
      _Step.subtitle =>
        true,
      _ => false,
    };
    if (!handled) return;
    setState(() {
      _me(text, step: _editable.contains(_step) ? _step : null);
      _input.clear();
      _awaitText = false;
      switch (_step) {
        case _Step.title:
          d.brief = d.brief.copyWith(title: text);
          _next(_Step.videoType);
        case _Step.videoType:
          d.brief = d.brief.copyWith(videoType: text);
          _next(_Step.platform);
        case _Step.platform:
          d.brief = d.brief.copyWith(platform: text);
          _next(_Step.purpose);
        case _Step.purpose:
          d.brief = d.brief.copyWith(purpose: text);
          _next(_Step.length);
        case _Step.length:
          _length = text;
          _syncDelivery();
          _prompt(_Step.orientation);
        case _Step.orientation:
          _orientation = text;
          _syncDelivery();
          _prompt(_Step.subtitle);
        case _Step.subtitle:
          _subtitle = '字幕$text';
          _syncDelivery();
          _next(_Step.due);
        default:
      }
    });
  }

  /// 選び直しができる質問。
  static const _editable = {
    _Step.title,
    _Step.videoType,
    _Step.platform,
    _Step.purpose,
    _Step.length,
    _Step.orientation,
    _Step.subtitle,
    _Step.due,
  };

  /// 長さ・向き・字幕がそろっていれば、納品条件に反映する。
  void _syncDelivery() {
    if (_length.isEmpty || _orientation.isEmpty || _subtitle.isEmpty) return;
    d.brief = d.brief
        .copyWith(deliveryTerms: [_length, _orientation, _subtitle].join('・'));
  }

  /// 質問ごとの選択肢。メニュー（回答のタップ）と、チャット末尾のボタンで共通。
  static const _choices = {
    _Step.videoType: ['会社紹介', 'スタッフ紹介', '採用PR', '社内用', '社長チャレンジ', 'その他'],
    _Step.platform: ['Instagram', 'TikTok', 'YouTube', 'Threads', 'X', 'その他'],
    _Step.purpose: ['認知を広げたい', '会社の魅力を伝えたい', '求人に繋げたい', '研修資料', 'その他'],
    _Step.length: ['30秒', '60秒', '直接入力'],
    _Step.orientation: ['縦型', '横型'],
    _Step.subtitle: ['あり', 'なし'],
  };

  /// 決定済みの回答をタップしたとき：メニューで選択肢を出し、選んだ内容で
  /// その回答を上書きする（チャットは増やさない。ほかの回答は変えない）。
  Future<void> _editAnswer(int index, Offset at) async {
    if (_picking) return;
    final msg = _msgs[index];
    final step = msg.step;
    if (step == null) return;
    if (step == _Step.due) {
      final picked = await _showDatePicker();
      if (picked == null || !mounted) return;
      setState(() {
        d.dueDate = picked;
        _msgs[index] = _Msg(true, '希望納期：${dateText(picked)}', step: _Step.due);
      });
      return;
    }
    final options = _choices[step];
    String? value;
    if (options == null) {
      // 依頼名：自由入力。
      value = await _askText('依頼名を入力してください', msg.text);
    } else {
      final screen = MediaQuery.sizeOf(context);
      final picked = await showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
            at.dx, at.dy, screen.width - at.dx, screen.height - at.dy),
        color: AppColors.ink,
        shape: RoundedRectangleBorder(
            side: BorderSide(color: AppColors.white.withValues(alpha: 0.16)),
            borderRadius: BorderRadius.circular(10)),
        items: [
          for (final o in options)
            PopupMenuItem<String>(
              value: o,
              child: Row(children: [
                SizedBox(
                    width: 24,
                    child: o == msg.text
                        ? const Icon(Icons.check,
                            size: 18, color: AppColors.white)
                        : null),
                Text(o, style: AppText.dark(14, weight: FontWeight.w400)),
              ]),
            ),
        ],
      );
      if (picked == null || !mounted) return;
      value = picked;
      if (picked == '直接入力') {
        final now = int.tryParse(msg.text.replaceAll('秒', ''));
        final sec = await _pickSeconds(now ?? 45);
        value = sec == null ? null : '$sec秒';
      } else if (picked == 'その他') {
        value = await _askText(
            '内容を入力してください', options.contains(msg.text) ? '' : msg.text);
      }
    }
    if (value == null || value.trim().isEmpty || !mounted) return;
    final text = value.trim();
    setState(() {
      _msgs[index] = _Msg(true, text, step: step);
      switch (step) {
        case _Step.title:
          d.brief = d.brief.copyWith(title: text);
        case _Step.videoType:
          d.brief = d.brief.copyWith(videoType: text);
        case _Step.platform:
          d.brief = d.brief.copyWith(platform: text);
        case _Step.purpose:
          d.brief = d.brief.copyWith(purpose: text);
        case _Step.length:
          _length = text;
          _syncDelivery();
        case _Step.orientation:
          _orientation = text;
          _syncDelivery();
        case _Step.subtitle:
          _subtitle = '字幕$text';
          _syncDelivery();
        default:
      }
    });
  }

  /// 動画の長さを、ドラム式ピッカーで秒単位に選ぶ（1〜600秒）。キャンセルなら null。
  Future<int?> _pickSeconds(int initial) {
    var selected = initial.clamp(1, 600);
    final controller = FixedExtentScrollController(initialItem: selected - 1);
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.ink,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 300,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(children: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('キャンセル')),
                Expanded(
                    child:
                        Center(child: Text('動画の長さ', style: AppText.dark(16)))),
                TextButton(
                    onPressed: () => Navigator.of(context).pop(selected),
                    child: const Text('決定')),
              ]),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: controller,
                itemExtent: 40,
                backgroundColor: AppColors.ink,
                onSelectedItemChanged: (i) => selected = i + 1,
                children: [
                  for (var n = 1; n <= 600; n++)
                    Center(
                        child: Text('$n秒',
                            style: AppText.dark(20, weight: FontWeight.w400))),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// 1行の入力ダイアログ。キャンセルなら null。
  Future<String?> _askText(String title, String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(
            side: BorderSide(color: AppColors.white.withValues(alpha: 0.16)),
            borderRadius: BorderRadius.circular(15)),
        title: Text(title, style: AppText.dark(16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppText.dark(15, weight: FontWeight.w400),
          cursorColor: AppColors.white,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: AppColors.white),
              child: const Text('決定')),
        ],
      ),
    );
  }

  Future<void> _pick(
      {required bool video, bool image = false, bool bgm = false}) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final files = await FilePicker.pickFiles(
          type: video
              ? FileType.video
              : (image
                  ? FileType.image
                  : (bgm ? FileType.custom : FileType.any)),
          allowedExtensions: bgm ? const ['mp3'] : null);
      if (files.isEmpty || !mounted) return;
      final list = [for (final f in files) await UploadFile.fromPicked(f)];
      if (!mounted) return;
      final tooBig = list.where((f) => f.size > kMaxFileBytes);
      if (tooBig.isNotEmpty) {
        throw StateError(
            '${tooBig.first.name} は大きすぎます（上限 ${kMaxFileBytes ~/ 1024 ~/ 1024}MB）');
      }
      setState(() {
        final target = video ? d.videos : d.references;
        target.addAll(list);
        _me('${video ? '動画' : (image ? '画像' : (bgm ? 'BGM' : '参考資料'))}を添付：${list.map((f) => f.name).join('、')}');
        _say(_step == _Step.video
            ? '添付しました。追加するか「添付を完了」を押してください。'
            : '添付しました。続けて質問にお答えください。');
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添付できませんでした。再度選択してください。\n$e')));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _attachments() async {
    FocusScope.of(context).unfocus();
    final kind = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.ink,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
                textColor: AppColors.white,
                title: const Text('ファイルを添付'),
                subtitle: Text('回答の途中でも追加できます',
                    style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.7)))),
            for (final item in [
              ('video', Icons.video_library_outlined, '編集する動画'),
              ('image', Icons.photo_library_outlined, '参考画像・写真'),
              ('bgm', Icons.music_note_outlined, 'BGM（mp3）'),
              ('file', Icons.insert_drive_file_outlined, '参考動画・ファイル'),
            ])
              ListTile(
                leading: Icon(item.$2, color: AppColors.white),
                textColor: AppColors.white,
                title: Text(item.$3),
                onTap: () => Navigator.pop(context, item.$1),
              ),
          ]),
        ),
      ),
    );
    if (kind == null || !mounted) return;
    await _pick(
        video: kind == 'video', image: kind == 'image', bgm: kind == 'bgm');
  }

  void _choose(String text) {
    _input.text = text;
    _send();
  }

  /// 日付選択（日本語のカレンダー）。キャンセルなら null。
  Future<DateTime?> _showDatePicker() {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: d.dueDate != null &&
              !d.dueDate!.isBefore(DateTime(now.year, now.month, now.day))
          ? d.dueDate!
          : now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (context, child) => Theme(
        data: ThemeData.dark(useMaterial3: true).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.blue,
            onPrimary: AppColors.white,
            // 背景は透けない単色（ink）。
            surface: AppColors.ink,
            onSurface: AppColors.white,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: AppColors.ink),
          // 「キャンセル」「OK」はテキストボタンではなく、枠付き／塗りのボタンにする。
          datePickerTheme: DatePickerThemeData(
            cancelButtonStyle: OutlinedButton.styleFrom(
              foregroundColor: AppColors.white,
              side: BorderSide(color: AppColors.white.withValues(alpha: 0.55)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
            ),
            confirmButtonStyle: FilledButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
            ),
          ),
        ),
        child: child!,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await _showDatePicker();
    if (picked == null || !mounted) return;
    setState(() {
      d.dueDate = picked;
      _me('希望納期：${dateText(picked)}', step: _Step.due);
      if (d.original != null) {
        // 指示書の修正では、添付は変えないので確認へ進む。
        _enterReview();
        _say('ありがとうございます。内容を確認したら「完了」を押してください。');
      } else {
        _next(_Step.video);
      }
    });
  }

  /// 「完了」：確認のポップアップのあと、指示内容の確認画面へ進む。
  Future<void> _complete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(
            side: BorderSide(color: AppColors.white.withValues(alpha: 0.16)),
            borderRadius: BorderRadius.circular(15)),
        title: Text('以上内容で依頼しますか？', style: AppText.dark(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('いいえ')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: AppColors.white),
              child: const Text('はい')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(_enterReview);
    await Navigator.of(context).pushNamed('/brief', arguments: d);
    if (!mounted) return;
    setState(() {
      _say('内容を直す場合は、直したい回答をタップして選び直してください。');
    });
  }

  /// 「その他」「直接入力」を選んだとき：選択肢を消して、自由入力を待つ。
  void _askFree(String label, String question) => setState(() {
        _me(label);
        _say(question);
        _awaitText = true;
      });

  List<Widget> _options() {
    if (_awaitText) return const [];
    switch (_step) {
      case _Step.video:
        // 動画・画像は、入力欄の左のクリップから追加する。完了は入力欄の位置の「完了」ボタン。
        return const [];
      case _Step.due:
        return [AppChip('納期を選ぶ', onTap: _pickDate)];
      case _Step.review:
        // 直したい回答は、チャットの回答をタップして選び直す。
        return const [];
      case _Step.length:
        return [
          AppChip('30秒', onTap: () => _choose('30秒')),
          AppChip('60秒', onTap: () => _choose('60秒')),
          AppChip('直接入力', onTap: () async {
            final sec = await _pickSeconds(45);
            if (sec != null) _choose('$sec秒');
          }),
        ];
      case _Step.orientation:
        return [
          AppChip('縦型', onTap: () => _choose('縦型')),
          AppChip('横型', onTap: () => _choose('横型')),
        ];
      case _Step.subtitle:
        return [
          AppChip('あり', onTap: () => _choose('あり')),
          AppChip('なし', onTap: () => _choose('なし')),
        ];
      default:
        final choices = _choices[_step] ?? const <String>[];
        return [
          for (final label in choices)
            AppChip(label,
                onTap: label == 'その他'
                    ? () => _askFree('その他', '内容を入力してください。')
                    : () => _choose(label))
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final textStep = const {
      _Step.title,
      _Step.videoType,
      _Step.platform,
      _Step.purpose,
    }.contains(_step);
    final freeInput = textStep || _awaitText;
    final options = _options();
    // ナビゲーターが連続して話すときは、連続の最初のメッセージを画面トップに出す。
    var lastQuestion = _msgs.lastIndexWhere((m) => !m.mine);
    while (lastQuestion > 0 && !_msgs[lastQuestion - 1].mine) {
      lastQuestion--;
    }
    _scrollToLatestQuestion();
    return Scaffold(
      backgroundColor: AppColors.ink,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(title: d.original == null ? '指示作成' : '指示書の修正'),
            Expanded(
              child: BottomAlignedScroll(
                alignTop: true,
                latestOnTop: true,
                controller: _scroll,
                children: [
                  for (var i = 0; i < _msgs.length; i++)
                    KeyedSubtree(
                      key: i == lastQuestion ? _latestKey : null,
                      child: _ChatBubble(_msgs[i],
                          onTap: _msgs[i].mine &&
                                  _msgs[i].step != null &&
                                  !_picking
                              ? (at) => _editAnswer(i, at)
                              : null),
                    ),
                  if (_picking)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('添付ファイルを読み込んでいます…',
                          style: AppText.dark(14, weight: FontWeight.w400)),
                    ),
                  if (d.original == null)
                    for (final file in [...d.videos, ...d.references])
                      ListTile(
                        dense: true,
                        tileColor: AppColors.white.withValues(alpha: 0.08),
                        textColor: AppColors.white,
                        iconColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                            side: BorderSide(
                                color: AppColors.white.withValues(alpha: 0.16)),
                            borderRadius: BorderRadius.circular(AppRadius.lg)),
                        leading: d.videos.contains(file)
                            ? const Icon(Icons.videocam_outlined)
                            : const AppIcon(AppIcons.attachFile,
                                size: 24, color: AppColors.white),
                        title: Text(file.name,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            '${(file.size / 1024 / 1024).toStringAsFixed(1)} MB'),
                        trailing: IconButton(
                          tooltip: '添付を削除',
                          icon: const Icon(Icons.close),
                          onPressed: _picking
                              ? null
                              : () => setState(() {
                                    d.videos.remove(file);
                                    d.references.remove(file);
                                  }),
                        ),
                      ),
                  if (options.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: r.y(10)),
                      // 選択肢は、ユーザー側（右）に縦に並べる。
                      // 幅は、いちばん長い選択肢にそろえる。
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: IntrinsicWidth(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < options.length; i++) ...[
                                  if (i > 0) SizedBox(height: r.y(8)),
                                  options[i],
                                ],
                              ]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _InputBar(
              controller: _input,
              enabled: freeInput,
              onSend: _send,
              onAttach: _picking || d.original != null ? null : _attachments,
              // 添付を選んでいる間は、入力欄を「完了」ボタンにする（動画が1つ以上で押せる）。
              attaching: _step == _Step.video || _step == _Step.review,
              onDone:
                  _picking || (_step == _Step.video && d.attachmentCount == 0)
                      ? null
                      : _complete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble(this.message, {this.onTap});
  final _Msg message;

  /// 回答のバブルをタップしたときの動作（メニューで選び直し）。タップ位置を渡す。
  final void Function(Offset at)? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: onTap == null ? null : (d) => onTap!(d.globalPosition),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          mainAxisAlignment:
              message.mine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.mine) ...[
              ClipOval(
                  child: Image.asset('assets/navigater.png',
                      width: 38, height: 38, fit: BoxFit.cover)),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!message.mine)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text('ナビゲーター',
                          style: AppText.dark(12,
                              weight: FontWeight.w500,
                              color: AppColors.white.withValues(alpha: 0.7))),
                    ),
                  Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * .73),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: message.mine
                          ? AppColors.blue
                          : AppColors.white.withValues(alpha: 0.08),
                      border: message.mine
                          ? null
                          : Border.all(
                              color: AppColors.white.withValues(alpha: 0.16)),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(message.mine ? 18 : 4),
                        topRight: Radius.circular(message.mine ? 4 : 18),
                        bottomLeft: const Radius.circular(18),
                        bottomRight: const Radius.circular(18),
                      ),
                    ),
                    child: Text(message.text,
                        style: message.mine
                            ? AppText.noto(15,
                                weight: FontWeight.w400,
                                color: AppColors.white,
                                height: 1.5)
                            : AppText.dark(15,
                                weight: FontWeight.w400, height: 1.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar(
      {required this.controller,
      required this.enabled,
      required this.onSend,
      this.onAttach,
      this.attaching = false,
      this.onDone});

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback? onAttach;

  /// 添付を選んでいる間は true。入力欄と送信の代わりに「完了」ボタンを出す。
  final bool attaching;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.08),
          border: Border(
              top: BorderSide(color: AppColors.white.withValues(alpha: 0.16)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
              tooltip: 'ファイルを添付',
              onPressed: onAttach,
              icon: AppIcon(AppIcons.attachFile,
                  size: 32, color: AppColors.white.withValues(alpha: 0.7))),
          if (attaching)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4, right: 8),
                child: FilledButton(
                  onPressed: onDone,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.blue,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24))),
                  child: Text('完了', style: AppText.dark(16)),
                ),
              ),
            )
          else ...[
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                style: AppText.dark(15, weight: FontWeight.w400),
                cursorColor: AppColors.white,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.ink,
                  hintStyle: AppText.dark(15,
                      weight: FontWeight.w400,
                      color: AppColors.white.withValues(alpha: 0.7)),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                  hintText: enabled ? 'メッセージを入力' : '選択肢から回答',
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) => IconButton(
                tooltip: '回答を送信',
                onPressed:
                    enabled && value.text.trim().isNotEmpty ? onSend : null,
                icon: AppIcon(AppIcons.send,
                    size: 32,
                    color: enabled && value.text.trim().isNotEmpty
                        ? AppColors.blue
                        : AppColors.white.withValues(alpha: 0.16)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
