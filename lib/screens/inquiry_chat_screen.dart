import 'package:flutter/material.dart' hide Text;

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../data/services.dart';
import '../domain/brief.dart';
import '../domain/request_status.dart';
import '../domain/video_request.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/voice_input.dart';
import '../widgets/ruby_text.dart';

/// 問合せ履歴の1件の発言（編集者の問合せ、または依頼者の回答）。
class _HistoryMsg {
  const _HistoryMsg(
      {required this.fromRequester,
      required this.sender,
      required this.text,
      required this.at,
      required this.round});
  final bool fromRequester;
  final String sender;
  final String text;
  final DateTime? at;
  final int round;
}

/// 問合せ履歴を、LINEのように時系列の発言に並べる。複数の編集者の問合せも、依頼者の回答も同じ並びで出す。
/// 回答が空のもの（まとめて答えた問合せ）は、回答の吹き出しを出さない。
List<_HistoryMsg> _historyMessages(List<Inquiry> items) {
  final far = DateTime(9999);
  final list = <_HistoryMsg>[
    for (final i in items) ...[
      _HistoryMsg(
          fromRequester: false,
          sender: '${i.editorName ?? '編集者'}（編集者）',
          text: i.question,
          at: i.askedAt,
          round: i.round),
      if (i.answer != null && i.answer!.isNotEmpty)
        _HistoryMsg(
            fromRequester: true,
            sender: '依頼者',
            text: i.answer!,
            at: i.answeredAt,
            round: i.round),
    ],
  ];
  // 時刻が未確定（保存直後）のものは最後。同じ時刻なら、問合せの番号順で問合せを先に。
  list.sort((a, b) {
    final c = (a.at ?? far).compareTo(b.at ?? far);
    if (c != 0) return c;
    final r = a.round.compareTo(b.round);
    if (r != 0) return r;
    return (a.fromRequester ? 1 : 0).compareTo(b.fromRequester ? 1 : 0);
  });
  return list;
}

/// 問合せチャットの結果。[submit] が true なら、回答を送信済み。
class InquiryResult {
  const InquiryResult(this.reply, {required this.submit});
  final String reply;
  final bool submit;
}

/// 問合せへの回答チャット。ナビゲーターが問合せを伝え、依頼者がこの画面のまま
/// 文字または音声で回答する。回答したら、その文章を返して前の画面へ戻る。
class InquiryChatScreen extends StatefulWidget {
  const InquiryChatScreen(
      {super.key,
      required this.request,
      required this.brief,
      this.dueDate,
      this.initialReply});
  final VideoRequest request;

  /// 依頼内容の画面で直した最新の指示書と納期。回答する、で再送信する内容。
  final Brief brief;
  final DateTime? dueDate;

  /// 前に入力して「依頼内容に戻る」で戻った回答。あれば回答済みの状態から始める。
  final String? initialReply;

  @override
  State<InquiryChatScreen> createState() => _InquiryChatScreenState();
}

class _InquiryChatScreenState extends State<InquiryChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _voice = VoiceInput();
  final _msgs = <({bool mine, String text})>[];
  String? _notice;
  String? _reply;
  bool _sending = false;

  /// これまでの問合せと回答（全員分）。読み込めるまでは、依頼の最新の問合せだけを出す。
  List<Inquiry>? _history;

  static const _ackText =
      '回答を受け付けました。このまま編集者へ送るときは「回答する」、指示書も直したいときは「依頼内容に戻る」を押してください。';

  void _load() {
    Services.repo.watchInquiries(widget.request.id).first.then((h) {
      if (mounted) {
        setState(() => _history = h);
        _scrollToEnd();
      }
    }).catchError((_) {});
    final prev = widget.initialReply;
    if (prev != null && prev.isNotEmpty) {
      _reply = prev;
      _msgs.add((mine: true, text: prev));
      _msgs.add((mine: false, text: _ackText));
    } else {
      _msgs.add((mine: false, text: '回答を入力してください。音声でも入力できます。'));
    }
  }

  @override
  void initState() {
    super.initState();
    _voice.addListener(_onVoice);
    _load();
  }

  void _onVoice() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _voice.removeListener(_onVoice);
    _voice.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// これまでの問合せと回答。履歴が読めない・空のときは、依頼に残る最新の問合せを出す。
  List<Widget> _historyBubbles() {
    final h = _history;
    if (h == null || h.isEmpty) {
      final q = widget.request;
      return [
        _Bubble(false, q.reviewReason ?? '問い合わせ内容はありません。',
            sender: '${q.editorName ?? '編集者'}（編集者）', light: true),
      ];
    }
    return [
      for (final m in _historyMessages(h))
        _Bubble(m.fromRequester, m.text,
            sender: m.sender, light: !m.fromRequester),
    ];
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut);
        }
      });

  void _send() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    _voice.cancel();
    setState(() {
      _reply = t;
      _msgs.add((mine: true, text: t));
      _msgs.add((mine: false, text: _ackText));
      _input.clear();
    });
    _scrollToEnd();
  }

  /// 回答を、指示書の「その他指示」に追記して編集者へ再送信する。
  Future<void> _submit() async {
    final uid = Services.uid;
    final reply = _reply;
    if (_sending || uid == null || reply == null) return;
    final brief = widget.brief;
    final errors = BriefValidation.validate(
        brief: brief,
        dueDate: widget.dueDate,
        attachmentCount: widget.request.attachments.length,
        now: DateTime.now());
    if (errors.isNotEmpty) {
      setState(
          () => _notice = 'エラー：${errors.values.join('、')}。「依頼内容に戻る」で直してください');
      return;
    }
    setState(() {
      _sending = true;
      _notice = null;
    });
    try {
      await Services.repo.resubmitBrief(
          requestId: widget.request.id,
          uid: uid,
          brief: brief,
          dueDate: widget.dueDate!,
          answer: reply);
      if (mounted) {
        Navigator.pop(context, InquiryResult(reply, submit: true));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _notice = 'エラー：回答を送信できませんでした。通信を確認して、もう一度「回答する」を押してください。\n$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final answered = _reply != null;
    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            const AppHeader(title: '問合せ'),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                children: [
                  const _Bubble(false, '依頼者への問合せの履歴です。編集者の問合せに、まとめて回答してください。'),
                  ..._historyBubbles(),
                  for (final m in _msgs) _Bubble(m.mine, m.text),
                ],
              ),
            ),
            if (answered && _notice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                child: Text(_notice!,
                    style: AppText.dark(12,
                        weight: FontWeight.w400, color: AppColors.amber)),
              ),
            if (answered)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _sending
                          ? null
                          : () => Navigator.pop(
                              context, InquiryResult(_reply!, submit: false)),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: AppColors.bg,
                          foregroundColor: AppColors.blue,
                          side: BorderSide(color: AppColors.blue),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24))),
                      child: Text('依頼内容に戻る',
                          style: AppText.dark(15, color: AppColors.blue)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _sending ? null : _submit,
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: AppColors.blue,
                          foregroundColor: AppColors.onBlue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24))),
                      child: _sending
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.white))
                          : Text('回答する', style: AppText.dark(15)),
                    ),
                  ),
                ]),
              )
            else
              _bar(),
          ]),
          // 音声入力中は、画面の中心にマイクを大きく出す（操作は通す）。
          VoiceListeningOverlay(listening: _voice.listening),
        ]),
      ),
    );
  }

  Widget _bar() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
            color: AppColors.gray,
            border: Border(
                top: BorderSide(
                    color: AppColors.white.withValues(alpha: 0.16)))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if ((_voice.notice ?? _notice) != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Text((_voice.notice ?? _notice)!,
                  style: AppText.dark(12,
                      weight: FontWeight.w400, color: AppColors.amber)),
            ),
          Row(children: [
            VoiceMicButton(voice: _voice, controller: _input),
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                style: AppText.dark(15, weight: FontWeight.w400),
                cursorColor: AppColors.white,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bg,
                  isDense: true,
                  hintText: _voice.listening ? '聞き取り中です…' : '回答を入力',
                  hintStyle: AppText.dark(15,
                      weight: FontWeight.w400,
                      color: AppColors.white.withValues(alpha: 0.7)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _input,
              builder: (_, v, __) => IconButton(
                tooltip: '回答を送信',
                onPressed: v.text.trim().isEmpty ? null : _send,
                icon: Icon(Icons.send,
                    size: 28,
                    color: v.text.trim().isEmpty
                        ? AppColors.white.withValues(alpha: 0.16)
                        : AppColors.blue),
              ),
            ),
          ]),
        ]),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.mine, this.text,
      {this.sender = 'ナビゲーター', this.light = false});
  final bool mine;
  final String text;

  /// 相手側の吹き出しに添える名前。
  final String sender;

  /// 白い背景で出す（編集者の問合せ）。ナビゲーターの案内は黒系、依頼者の回答は青。
  final bool light;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          mainAxisAlignment:
              mine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine) ...[
              sender == 'ナビゲーター'
                  ? ClipOval(
                      child: Image.asset('assets/navigater.png',
                          width: 38, height: 38, fit: BoxFit.cover))
                  : CircleAvatar(
                      radius: 19,
                      backgroundColor: AppColors.white.withValues(alpha: 0.16),
                      child: Text(sender.characters.first,
                          style: AppText.dark(15))),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!mine)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(sender,
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
                      color: mine
                          ? AppColors.blue
                          : (light ? AppColors.white : AppColors.gray),
                      border: (mine || light)
                          ? null
                          : Border.all(
                              color: AppColors.white.withValues(alpha: 0.16)),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(mine ? 18 : 4),
                        topRight: Radius.circular(mine ? 4 : 18),
                        bottomLeft: const Radius.circular(18),
                        bottomRight: const Radius.circular(18),
                      ),
                    ),
                    child: Text(text,
                        style: mine
                            ? AppText.noto(15,
                                weight: FontWeight.w400,
                                color: AppColors.white,
                                height: 1.5)
                            : light
                                ? AppText.noto(15,
                                    weight: FontWeight.w400,
                                    color: AppColors.ink,
                                    height: 1.5)
                                : AppText.dark(15,
                                    weight: FontWeight.w400, height: 1.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// 問合せ履歴。編集者・依頼者のどちらが開いても同じ画面で、ナビゲーターの案内に続けて問合せ（左）と回答（右）を並べて見られる（入力はできない）。
class InquiryHistoryScreen extends StatelessWidget {
  const InquiryHistoryScreen(
      {super.key, required this.request, this.asEditor = false});
  final VideoRequest request;

  /// 互換のために残している。表示は編集者・依頼者で同じ。
  final bool asEditor;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        drawer: const AppDrawer(),
        body: SafeArea(
          child: Column(children: [
            const AppHeader(title: '問合せ履歴'),
            Expanded(
              child: StreamBuilder<List<Inquiry>>(
                stream: Services.repo.watchInquiries(request.id),
                builder: (context, snap) {
                  final items = [...?snap.data];
                  // いま届いている問合せが履歴にまだ無いときは、依頼の値から補う。
                  final reason = request.reviewReason;
                  if (request.status == RequestStatus.needsInfo &&
                      reason != null &&
                      reason.isNotEmpty &&
                      !items.any((i) => i.round == request.reviewRound)) {
                    items.add(Inquiry(
                        round: request.reviewRound,
                        question: reason,
                        editorName: request.editorName,
                        askedAt: null,
                        answer: null,
                        answeredAt: null));
                  }
                  if (items.isEmpty) {
                    return Center(
                        child: Text('問合せの履歴はありません',
                            style: AppText.dark(14, weight: FontWeight.w400)));
                  }
                  final msgs = _historyMessages(items);
                  // 依頼者の回答を待っている問合せがあるか。
                  final waiting = request.status == RequestStatus.needsInfo &&
                      items.any((i) => i.answer == null);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                    children: [
                      // 編集者・依頼者・ほかの編集者のだれが開いても同じ表示。
                      // ナビゲーターの案内から始め、編集者の問合せ（左）と依頼者の回答（右）を時系列で並べる。
                      const _Bubble(false,
                          'この依頼の問合せと回答の履歴です。編集者からの問合せは左、依頼者の回答は右に表示します。'),
                      for (final m in msgs)
                        _Bubble(m.fromRequester, m.text,
                            sender: m.sender, light: !m.fromRequester),
                      if (waiting) const _Bubble(false, '依頼者の回答をお待ちください。'),
                    ],
                  );
                },
              ),
            ),
          ]),
        ),
      );
}
