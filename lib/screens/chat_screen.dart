import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../data/storage_service.dart';
import '../domain/brief.dart';
import '../domain/draft.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/status_style.dart';

enum _Step {
  title,
  videoType,
  platform,
  audience,
  purpose,
  structure,
  delivery,
  video,
  reference,
  sceneAsk,
  sceneTitle,
  sceneBody,
  due,
  review,
}

class _Msg {
  const _Msg(this.mine, this.text);
  final bool mine;
  final String text;
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
  String _sceneTitle = '';
  bool _picking = false;

  /// 確認画面から戻って1項目だけ直している間は、直し終えたら review に戻る。
  bool _fixing = false;

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
    super.dispose();
  }

  void _say(String t) => _msgs.add(_Msg(false, t));
  void _me(String t) => _msgs.add(_Msg(true, t));

  void _enterReview() {
    _step = _Step.review;
    _fixing = false;
  }

  void _prompt(_Step s) {
    _step = s;
    _say(switch (s) {
      _Step.title => '依頼名（動画のタイトル）を入力してください。',
      _Step.videoType => 'どんな動画ですか？選択するか、自由に入力してください。',
      _Step.platform => 'どこに投稿しますか？',
      _Step.audience => '誰に見てもらいたい動画ですか？（年齢層・興味など）',
      _Step.purpose => '動画の目的を教えてください。（例：新商品の認知拡大）',
      _Step.structure => '動画の構成を教えてください。（例：冒頭で商品紹介 → 使い方 → 購入案内）',
      _Step.delivery => '納品条件を教えてください。長さ・縦横比・形式・字幕・BGMの希望を入力できます。',
      _Step.video => '撮影した動画を添付してください。',
      _Step.reference => '参考資料があれば添付してください。（任意）',
      _Step.sceneAsk => '場面ごとの指示を追加しますか？',
      _Step.sceneTitle => '場面の名前を入力してください。（例：オープニング）',
      _Step.sceneBody => 'この場面の指示を入力してください。',
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
      _Step.audience ||
      _Step.title ||
      _Step.purpose ||
      _Step.structure ||
      _Step.delivery ||
      _Step.sceneTitle ||
      _Step.sceneBody =>
        true,
      _ => false,
    };
    if (!handled) return;
    setState(() {
      _me(text);
      _input.clear();
      switch (_step) {
        case _Step.title:
          d.brief = d.brief.copyWith(title: text);
          _next(_Step.videoType);
        case _Step.videoType:
          d.brief = d.brief.copyWith(videoType: text);
          _next(_Step.platform);
        case _Step.platform:
          d.brief = d.brief.copyWith(platform: text);
          _next(_Step.audience);
        case _Step.audience:
          d.brief = d.brief.copyWith(audience: text);
          _next(_Step.purpose);
        case _Step.purpose:
          d.brief = d.brief.copyWith(purpose: text);
          _next(_Step.structure);
        case _Step.structure:
          d.brief = d.brief.copyWith(structure: text);
          _next(_Step.delivery);
        case _Step.delivery:
          d.brief = d.brief.copyWith(deliveryTerms: text);
          _next(d.original != null ? _Step.sceneAsk : _Step.video);
        case _Step.sceneTitle:
          _sceneTitle = text;
          _prompt(_Step.sceneBody);
        case _Step.sceneBody:
          d.brief = d.brief.copyWith(scenes: [
            ...d.brief.scenes,
            Scene(title: _sceneTitle, instruction: text)
          ]);
          _prompt(_Step.sceneAsk);
        default:
      }
    });
  }

  Future<void> _pick({required bool video, bool image = false}) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final files = await FilePicker.pickFiles(
          type:
              video ? FileType.video : (image ? FileType.image : FileType.any));
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
        _me('${video ? '動画' : '参考資料'}を添付：${list.map((f) => f.name).join('、')}');
        _say('添付しました。追加するか「添付を完了」を押してください。');
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

  void _choose(String text) {
    _input.text = text;
    _send();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: d.dueDate != null &&
              !d.dueDate!.isBefore(DateTime(now.year, now.month, now.day))
          ? d.dueDate!
          : now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      d.dueDate = picked;
      _me('希望納期：${dateText(picked)}');
      _enterReview();
      _say('ありがとうございます。「指示内容を確認する」で入力内容を確かめてください。');
    });
  }

  void _fix(_Step s, String label) {
    setState(() {
      _input.text = switch (s) {
        _Step.title => d.brief.title,
        _Step.videoType => d.brief.videoType,
        _Step.platform => d.brief.platform,
        _Step.audience => d.brief.audience,
        _Step.purpose => d.brief.purpose,
        _Step.structure => d.brief.structure,
        _Step.delivery => d.brief.deliveryTerms,
        _ => '',
      };
      _fixing = true;
      _say('$labelを直します。');
      _prompt(s);
    });
  }

  Future<void> _confirm() async {
    await Navigator.of(context).pushNamed('/brief', arguments: d);
    if (!mounted) return;
    setState(() {
      _say('どの項目を直しますか？');
    });
  }

  List<Widget> _options() {
    switch (_step) {
      case _Step.video:
        return [
          AppChip('動画を追加', onTap: _picking ? null : () => _pick(video: true)),
          if (d.videos.isNotEmpty)
            AppChip('添付を完了',
                onTap: _picking
                    ? null
                    : () => setState(() => _next(_Step.reference))),
        ];
      case _Step.reference:
        return [
          AppChip('画像を追加',
              onTap: _picking ? null : () => _pick(video: false, image: true)),
          AppChip('参考資料を追加',
              onTap: _picking ? null : () => _pick(video: false)),
          if (d.references.isNotEmpty)
            AppChip('添付を完了',
                onTap: _picking
                    ? null
                    : () => setState(() => _next(_Step.sceneAsk))),
          if (d.references.isEmpty)
            AppChip('資料なし',
                onTap: _picking
                    ? null
                    : () => setState(() {
                          _me('資料なし');
                          _next(_Step.sceneAsk);
                        })),
        ];
      case _Step.sceneAsk:
        return [
          AppChip('場面を追加',
              onTap: () => setState(() {
                    _me('場面を追加');
                    _prompt(_Step.sceneTitle);
                  })),
          AppChip('これで完了',
              onTap: () => setState(() {
                    _me('これで完了');
                    if (_fixing) {
                      _enterReview();
                    } else {
                      _prompt(_Step.due);
                    }
                  })),
        ];
      case _Step.due:
        return [AppChip('納期を選ぶ', onTap: _pickDate)];
      case _Step.review:
        return [
          AppChip('依頼名', onTap: () => _fix(_Step.title, '依頼名')),
          AppChip('動画の種類', onTap: () => _fix(_Step.videoType, '動画の種類')),
          AppChip('投稿先', onTap: () => _fix(_Step.platform, '投稿先')),
          AppChip('視聴者', onTap: () => _fix(_Step.audience, '視聴者')),
          AppChip('目的', onTap: () => _fix(_Step.purpose, '目的')),
          AppChip('構成', onTap: () => _fix(_Step.structure, '構成')),
          AppChip('納品条件', onTap: () => _fix(_Step.delivery, '納品条件')),
          if (d.original == null) ...[
            AppChip('動画', onTap: () => _fix(_Step.video, '動画')),
            AppChip('参考資料', onTap: () => _fix(_Step.reference, '参考資料')),
          ],
          AppChip('場面を追加', onTap: () => _fix(_Step.sceneTitle, '場面')),
          AppChip('納期', onTap: () => _fix(_Step.due, '納期')),
        ];
      default:
        final choices = switch (_step) {
          _Step.videoType => ['会社紹介', '商品紹介', '店舗紹介', '採用・PR', '社内・研修'],
          _Step.platform => ['Instagram リール', 'TikTok', 'YouTube', '社内・研修'],
          _Step.audience => ['20〜30代', 'ファミリー層', '企業・法人', '社員・スタッフ'],
          _Step.purpose => [
              '認知を広げたい',
              '商品の魅力を伝えたい',
              '来店・購入につなげたい',
              '使い方を説明したい'
            ],
          _Step.structure => [
              '導入 → 紹介 → まとめ',
              '課題 → 解決方法 → 購入案内',
              'インタビュー → 実際の様子 → メッセージ'
            ],
          _Step.delivery => [
              '30秒・縦型9:16・MP4・字幕あり・BGMおまかせ',
              '60秒・縦型9:16・MP4・字幕あり・BGMおまかせ',
              '3分・横型16:9・MP4・字幕あり・BGMなし'
            ],
          _ => <String>[],
        };
        return [
          for (final label in choices)
            AppChip(label, onTap: () => _choose(label))
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
      _Step.audience,
      _Step.purpose,
      _Step.structure,
      _Step.delivery,
      _Step.sceneTitle,
      _Step.sceneBody,
    }.contains(_step);
    final options = _options();
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(title: d.original == null ? '指示' : '指示書の修正'),
            Expanded(
              child: BottomAlignedScroll(
                children: [
                  for (final m in _msgs)
                    m.mine
                        ? MyMessage(m.text)
                        : AssistantMessage(
                            text: m.text, fixedWidth: m.text.length > 35),
                  if (_picking)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('添付ファイルを読み込んでいます…'),
                    ),
                  if (_step == _Step.video || _step == _Step.reference)
                    for (final file
                        in (_step == _Step.video ? d.videos : d.references))
                      ListTile(
                        dense: true,
                        leading: Icon(_step == _Step.video
                            ? Icons.videocam_outlined
                            : Icons.attach_file),
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
                                    (_step == _Step.video
                                            ? d.videos
                                            : d.references)
                                        .remove(file);
                                  }),
                        ),
                      ),
                  if (options.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: r.y(10)),
                      child: Wrap(
                          spacing: r.x(8),
                          runSpacing: r.y(8),
                          children: options),
                    ),
                ],
              ),
            ),
            if (_step == _Step.review)
              Padding(
                padding: EdgeInsets.all(r.x(5)),
                child: Material(
                  color: AppColors.amber,
                  borderRadius: BorderRadius.circular(r.x(20)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(r.x(20)),
                    onTap: _confirm,
                    child: SizedBox(
                      height: r.y(66),
                      width: double.infinity,
                      child: Center(
                        child: Text('指示内容を確認する',
                            style: AppText.noto(r.x(16),
                                color: Colors.white, height: 20.8 / 16)),
                      ),
                    ),
                  ),
                ),
              )
            else
              _InputBar(
                controller: _input,
                enabled: textStep,
                onSend: _send,
              ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar(
      {required this.controller, required this.enabled, required this.onSend});

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.all(r.x(5)),
      child: Container(
        constraints: BoxConstraints(minHeight: r.y(66)),
        padding: EdgeInsets.symmetric(horizontal: r.x(14), vertical: r.y(9)),
        decoration: BoxDecoration(
          color: AppColors.blue,
          borderRadius: BorderRadius.circular(r.x(20)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: r.x(14)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.ink),
                  borderRadius: BorderRadius.circular(r.x(16)),
                ),
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  style: AppText.noto(r.x(16), weight: FontWeight.w500),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: enabled ? 'ここに入力…' : '上の選択肢から選んでください',
                  ),
                ),
              ),
            ),
            SizedBox(width: r.x(8)),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) => IconButton(
                tooltip: '回答を送信',
                onPressed:
                    enabled && value.text.trim().isNotEmpty ? onSend : null,
                icon: Icon(Icons.send, size: r.x(24)),
                color: Colors.white,
                disabledColor: Colors.white38,
                constraints:
                    BoxConstraints(minWidth: r.x(48), minHeight: r.x(48)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
