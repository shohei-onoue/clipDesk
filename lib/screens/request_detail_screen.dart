import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_tokens.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../data/storage_service.dart';
import '../domain/brief.dart';
import '../domain/home_logic.dart';
import '../domain/request_status.dart';
import '../domain/staff_access.dart';
import '../domain/video_request.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_header.dart';
import '../widgets/role_builder.dart';
import '../widgets/status_style.dart';
import '../widgets/attachment_thumb.dart';
import '../widgets/hold_to_cancel_button.dart';
import '../widgets/save_menu.dart';
import '../widgets/submission_player.dart';
import '../widgets/video_player_dialog.dart';
import '../widgets/app_icon.dart';
import '../widgets/detail_widgets.dart';
import '../widgets/voice_message_dialog.dart';
import 'inquiry_chat_screen.dart';
import '../widgets/ruby_text.dart';

/// 案件詳細。依頼者は「動画承認」、編集者は「依頼確認／動画アップロード」を
/// この画面から行う（役割と状態で操作を出し分ける）。
class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: const AppBottomBar(),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(children: [
          // 問合せ中だけ「依頼内容」（依頼者が内容を直す画面）、それ以外は「依頼確認」。
          StreamBuilder<VideoRequest?>(
            stream: Services.repo.watchRequest(requestId),
            builder: (context, snap) => AppHeader(
                title: switch (snap.data?.status) {
              RequestStatus.pending => '依頼確認',
              RequestStatus.needsInfo => '依頼内容',
              _ => '依頼確認',
            }),
          ),
          Expanded(
            child: RoleBuilder(
              dark: true,
              builder: (context, uid, role) => StreamBuilder<VideoRequest?>(
                stream: Services.repo.watchRequest(requestId),
                builder: (context, snap) {
                  if (snap.hasError) {
                    // 権限のない案件は読み取りが拒否される。
                    return const _Notice('エラー：この案件を表示できません。権限を確認してください');
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(
                        child:
                            CircularProgressIndicator(color: AppColors.white));
                  }
                  final req = snap.data;
                  if (req == null) {
                    return const _Notice('この案件は見つかりません');
                  }
                  // 依頼主と編集担当が決まった依頼は、その二人だけが見られる。問合せ中は依頼主だけ。
                  if (isRequestLockedFor(req, uid, DateTime.now())) {
                    return _Notice(req.status == RequestStatus.needsInfo
                        ? '問合せ中の依頼は、依頼者のみ閲覧できます'
                        : 'この依頼は、依頼者と担当の編集者のみ閲覧できます');
                  }
                  // 立場は「メイン画面で選んだ立場」ではなく、権限と依頼の関係で決める。
                  // 編集者の権限があり、自分が出した依頼でなければ編集者として見る
                  // （両方の権限をもつスタッフが依頼者の立場のままでも、「受注」「問合せ」が出る）。
                  return StreamBuilder<StaffAccess>(
                    stream: Services.repo.watchAccess(uid),
                    builder: (context, access) {
                      final canEdit = access.data?.canEdit ?? false;
                      final effective = canEdit && req.requesterId != uid
                          ? UserRole.editor
                          : role;
                      return _Body(request: req, uid: uid, role: effective);
                    },
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.request, required this.uid, required this.role});
  final VideoRequest request;
  final String uid;
  final UserRole role;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _busy = false;

  VideoRequest get q => widget.request;

  // 問合せ中の依頼者が、ダイアログで直した内容（再送信するまでは画面の中だけ）。
  Brief? _briefEdit;

  /// 問合せチャットで入力して、まだ送信していない回答。
  String? _pendingReply;
  DateTime? _dueEdit;
  Brief get _b => _briefEdit ?? q.brief;
  DateTime? get _due => _dueEdit ?? q.dueDate;

  /// 編集者として見るか。自分が出した依頼は、立場（依頼者／編集者）に関わらず
  /// 依頼者（A）として見る。両方の権限をもつスタッフでも、依頼ごとに画面が切り替わる。
  bool get _isEditor =>
      widget.role == UserRole.editor && q.requesterId != widget.uid;

  /// この依頼を請け負っている編集者が自分か。
  bool get _isAssignee => q.editorId == widget.uid;

  /// 編集者が編集開始・問い合わせをしてよいか：担当がいなければ誰でも、いれば担当本人だけ。
  bool get _canTakeOrAsk => q.editorId == null || _isAssignee;

  /// 添付のファイル名をタップしたときのメニュー（変更・削除）。
  Future<void> _attachmentMenu(Attachment a, Offset at) async {
    final choice = await _pickMenu(at, const ['変更', '削除'], '');
    if (choice == null || !mounted) return;
    final keep = [
      for (final x in q.attachments)
        if (x.path != a.path) x
    ];
    if (choice == '削除') {
      if (keep.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添付は1件以上必要です。入れ替えるときは「変更」を選んでください')));
        return;
      }
      await _run(
          () => Services.repo
              .updateAttachments(requestId: q.id, uid: widget.uid, keep: keep),
          done: '添付を削除しました');
      return;
    }
    final files = await _pickFiles(single: true);
    if (files.isEmpty || !mounted) return;
    await _run(
        () => Services.repo.updateAttachments(
            requestId: q.id,
            uid: widget.uid,
            keep: keep,
            add: [(file: files.first, kind: a.kind)]),
        done: '添付を変更しました');
  }

  Future<void> _addAttachments() async {
    final files = await _pickFiles();
    if (files.isEmpty || !mounted) return;
    await _run(
        () => Services.repo.updateAttachments(
            requestId: q.id,
            uid: widget.uid,
            keep: q.attachments,
            add: [for (final f in files) (file: f, kind: _kindOf(f.name))]),
        done: '添付を追加しました');
  }

  static String _kindOf(String name) {
    final l = name.toLowerCase();
    return ['.mp4', '.mov', '.m4v', '.webm'].any(l.endsWith)
        ? 'video'
        : 'reference';
  }

  /// ファイルを選ぶ。大きすぎるものは選べない。
  Future<List<UploadFile>> _pickFiles({bool single = false}) async {
    try {
      final List<PlatformFile> picked;
      if (single) {
        final one = await FilePicker.pickFile();
        picked = [if (one != null) one];
      } else {
        picked = await FilePicker.pickFiles();
      }
      final list = [for (final f in picked) await UploadFile.fromPicked(f)];
      final tooBig = list.where((f) => f.size > kMaxFileBytes);
      if (tooBig.isNotEmpty) {
        throw StateError(
            '${tooBig.first.name} は大きすぎます（上限 ${kMaxFileBytes ~/ 1024 ~/ 1024}MB）');
      }
      return list;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ファイルを選べませんでした：$e')));
      }
      return const [];
    }
  }

  Future<void> _download(String path) async {
    final url = await Services.repo.downloadUrl(path);
    await launchUrl(Uri.parse(url));
  }

  /// 多重操作を防ぎつつ実行し、失敗は画面に出す。
  /// 成功したら true を返す。
  Future<bool> _run(Future<void> Function() action, {String? done}) async {
    if (_busy) return false;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
      return true;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('失敗しました：$e')));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// メッセージ入力（キーボード／音声）。キャンセルや空なら null。
  Future<String?> _askText(String title, String hint,
      {String sendLabel = '送信'}) async {
    final t = await showVoiceMessageDialog(context,
        title: title, hint: hint, sendLabel: sendLabel);
    return t == null || t.isEmpty ? null : t;
  }

  /// 「その他指示」の表示。以前の方式で書き足された問合せへの回答の行は出さない
  /// （問合せ・回答は、専用の行に表示する）。
  static String _plainNotes(String notes) => notes
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('【問合せへの回答】'))
      .join('\n')
      .trim();

  /// 指示書の各項目。編集できるときは、空の項目も出して内容の右側に編集アイコンを付ける。
  List<Widget> _briefRows(bool editable) {
    final b = _b;
    Widget row(String label, String value, Brief Function(Brief, String) apply,
        {bool multiline = false,
        bool required = false,
        bool always = false,
        List<String>? choices}) {
      if (value.isEmpty && !editable && !always) return const SizedBox.shrink();
      return DetailRow(label, value.isEmpty ? '未設定' : value,
          onEdit: editable
              ? (at) => _editBrief(label, value,
                  at: at,
                  choices: choices,
                  multiline: multiline,
                  required: required,
                  apply: apply)
              : null);
    }

    return [
      // 編集できない人（編集者）にも、依頼者と同じ項目を出す。空のときは「未設定」。
      row('動画の種類', b.videoType, (x, v) => x.copyWith(videoType: v),
          always: true, choices: BriefChoices.videoType),
      row('投稿先', b.platform, (x, v) => x.copyWith(platform: v),
          always: true, choices: BriefChoices.platform),
      row('目的', b.purpose, (x, v) => x.copyWith(purpose: v),
          multiline: true,
          required: true,
          always: true,
          choices: BriefChoices.purpose),
      DetailRow('納品条件', b.deliveryTerms.isEmpty ? '未設定' : b.deliveryTerms,
          onEdit: editable ? _editDelivery : null),
      row('その他指示', _plainNotes(b.otherNotes),
          (x, v) => x.copyWith(otherNotes: v),
          multiline: true, always: true),
      _InquiryHistoryRow(q, asEditor: _isEditor),
      for (var i = 0; i < b.scenes.length; i++) _sceneRow(i, editable),
    ];
  }

  Widget _sceneRow(int i, bool editable) {
    final sc = _b.scenes[i];
    final style = AppText.dark(14, weight: FontWeight.w400);
    Widget field(String text, bool title) => editable
        ? Align(
            alignment: Alignment.centerLeft,
            child: TapEditText(text.isEmpty ? '未設定' : text,
                label: '場面${i + 1}の${title ? '題名' : '指示'}',
                style: style,
                onTap: (_) => _editSceneField(i, title: title)))
        : Text(text, style: style);
    return DetailRow('場面${i + 1}', '',
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [field(sc.title, true), field(sc.instruction, false)]));
  }

  /// 1項目をダイアログ（キーボード／音声入力）で直す。保存すると画面の内容に反映する（再送信まで送信はしない）。
  /// 受付待ちの自分の依頼は、直したらすぐ保存する（受注前の内容編集。通知はしない）。
  /// 問合せ中は、「回答する」で再送信するまで画面の中だけで直す。
  bool get _autoSave =>
      !_isEditor &&
      q.requesterId == widget.uid &&
      q.status == RequestStatus.pending;

  Future<void> _commit({Brief? brief, DateTime? due}) async {
    setState(() {
      if (brief != null) _briefEdit = brief;
      if (due != null) _dueEdit = due;
    });
    if (!_autoSave) return;
    final d = _due;
    if (d == null) return;
    final ok = await _run(
        () => Services.repo.resubmitBrief(
            requestId: q.id, uid: widget.uid, brief: _b, dueDate: d),
        done: '内容を保存しました');
    if (!mounted) return;
    // 保存できたら以降は保存された内容を表示し、失敗したら直す前に戻す。
    setState(() {
      _briefEdit = null;
      _dueEdit = null;
    });
    if (!ok) return;
  }

  Future<void> _editBrief(String label, String current,
      {required Brief Function(Brief, String) apply,
      Offset? at,
      List<String>? choices,
      bool multiline = false,
      bool required = false}) async {
    String? v;
    if (choices != null && at != null) {
      // 選択肢のある項目は、チャットの回答と同じメニューで選ぶ。「その他」は直接入力。
      final picked = await _pickMenu(at, choices, current);
      if (picked == null || !mounted) return;
      v = picked == 'その他'
          ? await _inputText(label, choices.contains(current) ? '' : current)
          : picked;
    } else {
      v = await _inputText(label, current);
    }
    if (v == null || !mounted) return;
    if (required && v.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$labelは入力してください')));
      return;
    }
    await _commit(brief: apply(_b, v));
  }

  /// キーボード／音声で入力するダイアログ。キャンセルは null。
  Future<String?> _inputText(String label, String current) =>
      showVoiceMessageDialog(context,
          title: '$labelを編集',
          hint: '$labelを入力してください',
          sendLabel: '保存',
          initialText: current);

  /// チャットの回答メニューと同じ見た目の選択メニュー。選んだ項目、閉じたら null。
  Future<String?> _pickMenu(Offset at, List<String> options, String current) {
    final screen = MediaQuery.sizeOf(context);
    return showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          at.dx, at.dy, screen.width - at.dx, screen.height - at.dy),
      color: AppColors.bg,
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
                  child: o == current
                      ? Icon(Icons.check, size: 18, color: AppColors.white)
                      : null),
              Text(o, style: AppText.dark(14, weight: FontWeight.w400)),
            ]),
          ),
      ],
    );
  }

  /// 納品条件（長さ・向き・字幕）。チャットと同じ選択肢を順にメニューで選ぶ。
  Future<void> _editDelivery(Offset at) async {
    final parts = _b.deliveryTerms.split('・');
    final ok = parts.length == 3;
    final length = await _pickMenu(at, BriefChoices.length, ok ? parts[0] : '');
    if (length == null || !mounted) return;
    var len = length;
    if (length == '直接入力') {
      final t = await _inputText('長さ', ok ? parts[0] : '');
      if (t == null || t.isEmpty || !mounted) return;
      len = t;
    }
    final ori =
        await _pickMenu(at, BriefChoices.orientation, ok ? parts[1] : '');
    if (ori == null || !mounted) return;
    final sub = await _pickMenu(at, BriefChoices.subtitle, ok ? parts[2] : '');
    if (sub == null || !mounted) return;
    await _commit(brief: _b.copyWith(deliveryTerms: [len, ori, sub].join('・')));
  }

  Future<void> _editSceneField(int i, {required bool title}) async {
    final sc = _b.scenes[i];
    final v = await showVoiceMessageDialog(context,
        title: '場面${i + 1}の${title ? '題名' : '指示'}を編集',
        hint: '${title ? '題名' : '指示'}を入力してください',
        sendLabel: '保存',
        initialText: title ? sc.title : sc.instruction);
    if (v == null || !mounted) return;
    final scenes = [..._b.scenes];
    scenes[i] = Scene(
        title: title ? v : sc.title, instruction: title ? sc.instruction : v);
    await _commit(brief: _b.copyWith(scenes: scenes));
  }

  Future<void> _editDue([Offset? _]) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cur = (_due == null || _due!.isBefore(today)) ? today : _due!;
    final d = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 2)),
    );
    if (d == null || !mounted) return;
    await _commit(due: d);
  }

  /// 編集者が依頼者へ問い合わせる。メッセージを入力して送ると、ダッシュボードへ戻る
  /// （フロー図：音声入力 → ダッシュボード）。
  Future<void> _askRequester() async {
    final nav = Navigator.of(context);
    final message = await _askText('依頼者へのメッセージ', '確認したい内容を入力（音声でも入力できます）');
    if (message == null) return;
    final sent = await _run(
        () => Services.repo
            .askForInfo(requestId: q.id, uid: widget.uid, reason: message),
        done: '依頼者へ通知しました');
    if (sent) nav.maybePop();
  }

  /// 問合せ内容の確認と回答は、チャット画面で行う。回答はその他指示の末尾に追記する
  /// （「回答する」で再送信すると、編集者へ届く）。
  Future<void> _answerInquiry(VideoRequest q) async {
    final res = await Navigator.of(context).push<InquiryResult>(
        MaterialPageRoute(
            builder: (_) => InquiryChatScreen(
                request: q,
                brief: _b,
                dueDate: _due,
                initialReply: _pendingReply)));
    if (res == null || !mounted) return;
    if (res.submit) {
      // 送信済み。依頼は受付待ちに戻るので、ダッシュボードへ。
      Navigator.of(context).pushNamedAndRemoveUntil(
          '/home', (route) => route.settings.name == '/menu');
      return;
    }
    // 回答は問合せ履歴に残す。送信するまでは、この画面で控えておく。
    setState(() => _pendingReply = res.reply);
  }

  /// 依頼の取り消し（削除）。確認のあと、承認前の自分の依頼だけ消せる。
  /// 依頼の取り消し（削除）。「依頼取消」ボタンの長押しが完了したときに実行する。
  /// 承認前の自分の依頼だけ消せる。担当の編集者がいれば通知する。
  Future<void> _cancelRequest() async {
    if (!mounted) return;
    final nav = Navigator.of(context);
    await _run(() async {
      await Services.repo.cancelRequest(requestId: q.id, uid: widget.uid);
      // 依頼は削除されたので、ダッシュボードへ戻る。
      nav.pushNamedAndRemoveUntil(
          '/home', (route) => route.settings.name == '/menu');
    }, done: '依頼を取り消しました');
  }

  Future<void> _pickAndSubmit() async {
    final picked = await FilePicker.pickFile(type: FileType.video);
    if (picked == null) return;
    final file = await UploadFile.fromPicked(picked);
    await _run(
      () => Services.repo
          .submitVideo(requestId: q.id, uid: widget.uid, file: file),
      done: '動画を提出しました。依頼者へ確認を依頼しました',
    );
  }

  /// 画面上部のメッセージ。誰からのメッセージか分かるものは、文の中に名前（○○様）を入れる。
  /// 不特定多数へのもの（「編集者の受注待ちです」など）は、名前を入れない。
  /// 問合せ中の依頼者向けだけ、最新の問合せをした編集者の名前を、問合せの履歴から取る。
  Widget _noticeBar() {
    if (q.status == RequestStatus.needsInfo && !_isEditor) {
      return StreamBuilder<List<Inquiry>>(
        stream: Services.repo.watchInquiries(q.id),
        builder: (context, snap) {
          final list = snap.data ?? const <Inquiry>[];
          return NoticeBar(
              _notice(asker: list.isEmpty ? null : list.last.editorName));
        },
      );
    }
    return NoticeBar(_notice());
  }

  /// 名前があれば「○○様」、なければ [fallback]（「依頼者」「編集者」）。
  static String _honorific(String? name, String fallback) =>
      name == null || name.isEmpty ? fallback : '$name様';

  /// 画面上部のお知らせ。状態を語句で伝える。[asker] は、問合せ中に表示する、問い合わせた編集者の名前。
  String _notice({String? asker}) {
    final editor = _honorific(q.editorName, '編集者');
    final requester = _honorific(q.requesterName, '依頼者');
    switch (q.status) {
      case RequestStatus.pending:
        if (_isEditor && !_canTakeOrAsk) {
          return '$editorが担当しています。';
        }
        // 不特定多数へのメッセージ。依頼者本人と、それ以外で言い方を分ける。
        return !_isEditor && q.requesterId == widget.uid
            ? '編集担当者の受注待ちです。'
            : '編集者の受注待ちです。';
      case RequestStatus.needsInfo:
        if (_isEditor) {
          return '$requesterへ問合せ中です。回答をお待ちください。';
        }
        return '${_honorific(asker, '編集者')}より依頼内容の問い合わせが届いています。';
      case RequestStatus.editing:
        // 受注した編集者本人と、依頼者で言い方を分ける。
        if (_isEditor && _isAssignee) return 'あなたが受注した案件です。';
        if (!_isEditor && q.requesterId == widget.uid) {
          return '$editorが編集を承諾しました。';
        }
        return '$editorが編集中です。';
      case RequestStatus.review:
        if (q.approved) return '$requesterが承認済みです。編集者の投稿を待っています。';
        return _isEditor
            ? '動画を提出しました。$requesterの確認を待っています。'
            : '$editorよりアップされた動画を確認してください。';
      case RequestStatus.revision:
        // 修正の内容は、提出された動画の行の「！」アイコンから読む。
        return '$requesterより修正依頼が届きました。';
      case RequestStatus.posted:
        return '投稿済みです。';
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final repo = Services.repo;
    final s = q.status;

    // 納品条件の先頭が長さ（例：「30秒・縦型・字幕あり」）。
    final length = q.brief.deliveryTerms.isEmpty
        ? '未設定'
        : q.brief.deliveryTerms.split('・').first;
    // 編集を開始した編集者のログイン名。古い依頼で名前がないときは語句で示す。
    final editorLabel = q.editorName ?? (q.editorId == null ? '未定' : '決定済');

    // 依頼者本人は、承認前（投稿済みでない）なら依頼を取り消せる。
    final canCancel = !_isEditor &&
        q.requesterId == widget.uid &&
        s != RequestStatus.posted &&
        !q.approved;

    // 依頼者本人の、問合せ中：画面下の「指示書を修正して再送信」。
    final ownerInquiry = !_isEditor &&
        q.requesterId == widget.uid &&
        s == RequestStatus.needsInfo;

    // 受付待ちの依頼の、画面下のボタン。
    // 編集者：「受注」「問合せ」。依頼者本人：「依頼取消」（内容は各項目をタップして直す）。
    // 問合せ中（担当なし）の編集者は、「問合せ」だけ追加できる（受注は、依頼者の回答後の受付待ちから）。
    final askMore =
        _isEditor && s == RequestStatus.needsInfo && q.editorId == null;
    final intake = _isEditor && s == RequestStatus.pending && _canTakeOrAsk;
    final ownerPending =
        !_isEditor && q.requesterId == widget.uid && s == RequestStatus.pending;

    // 依頼者の動画確認（承認／修正依頼）。Figma の「修正の依頼」欄とボタン2つ。
    final reviewing = !_isEditor &&
        q.requesterId == widget.uid &&
        s == RequestStatus.review &&
        !q.approved;

    final editable = ownerInquiry || ownerPending;
    final videoLayout =
        !_isEditor && q.requesterId == widget.uid && s == RequestStatus.review;
    final Widget infoCard = DetailCard(children: [
      InfoRow('タイトル', _b.title,
          onEdit: editable
              ? (_) => _editBrief('タイトル', _b.title,
                  required: true, apply: (b, v) => b.copyWith(title: v))
              : null),
      InfoRow('納期', dateText(_due), onEdit: editable ? _editDue : null),
      InfoRow('長さ', length),
      InfoRow('担当', editorLabel),
    ]);
    final Widget briefCard = DetailCard(children: [
      Text('指示書', style: AppText.dark(r.x(16))),
      ..._briefRows(editable),
    ]);
    final Widget attachCard = q.approved
        ? DetailCard(children: [
            Row(children: [
              Expanded(child: Text('添付資料', style: AppText.dark(r.x(16)))),
            ]),
            Padding(
                padding: EdgeInsets.only(top: r.y(6)),
                child: Text('承認済みのため、添付資料は削除しました。\n承認された動画のみ保管しています。',
                    style: AppText.dark(r.x(14), weight: FontWeight.w400))),
          ])
        : DetailCard(children: [
            // タイトルと同じ行の右端に、資料の追加ボタン（受付待ちの自分の依頼と、動画確認中の自分の依頼）。
            Row(children: [
              Expanded(child: Text('添付資料', style: AppText.dark(r.x(16)))),
              if (ownerPending || reviewing)
                IconButton(
                  tooltip: '資料を追加',
                  onPressed: _busy
                      ? null
                      : () {
                          // 動画確認画面では、この欄は資料のダイアログの中にある。
                          // 追加が済むと一覧が変わるので、ダイアログを閉じてから追加する。
                          if (videoLayout) Navigator.of(context).pop();
                          _addAttachments();
                        },
                  // ダウンロードアイコン（Icons.download）と同じ24px。
                  icon: AppIcon(AppIcons.addCircle,
                      size: 24, color: AppColors.white),
                ),
            ]),
            // ダウンロードは編集者権限のスタッフだけ。それ以外は動画の再生で閲覧する。
            StreamBuilder<StaffAccess>(
              stream: Services.repo.watchAccess(widget.uid),
              builder: (context, snap) {
                final canDownload = snap.data?.canEdit ?? false;
                return Column(children: [
                  for (final a in q.attachments)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      textColor: AppColors.white,
                      iconColor: AppColors.white,
                      leading: InkWell(
                        onTap: () => showAttachmentDialog(context,
                            attachment: a,
                            onDownload:
                                canDownload ? () => _download(a.path) : null),
                        child: switch (attachmentTypeOf(a)) {
                          AttachmentType.video =>
                            const Icon(Icons.play_circle_outline),
                          AttachmentType.image =>
                            const Icon(Icons.image_outlined),
                          AttachmentType.audio =>
                            const Icon(Icons.music_note_outlined),
                          AttachmentType.other => AppIcon(AppIcons.attachFile,
                              size: 24, color: AppColors.white),
                        },
                      ),
                      // 受付待ちの自分の依頼では、ファイル名をタップして「変更」「削除」を選ぶ。
                      title: ownerPending
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: TapEditText(a.name,
                                  label: '${a.name}を変更・削除',
                                  style:
                                      AppText.dark(14, weight: FontWeight.w400),
                                  onTap: (at) => _attachmentMenu(a, at)),
                            )
                          // 編集できない人にも、同じ文字の形（下線だけ無し）で出す。
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: Text(a.name,
                                  style: AppText.dark(14,
                                      weight: FontWeight.w400)),
                            ),
                      trailing: canDownload
                          ? Builder(
                              // タップで保存先のメニューを開く（端末・Dropbox・Google ドライブ・OneDrive）。
                              builder: (bctx) => IconButton(
                                tooltip: 'ダウンロード（保存先を選ぶ）',
                                color: AppColors.white,
                                icon: const Icon(Icons.download),
                                onPressed: () => showSaveMenu(bctx,
                                    path: a.path, name: a.name),
                              ),
                            )
                          : null,
                      onTap: ownerPending
                          ? null
                          : () => showAttachmentDialog(context,
                              attachment: a,
                              onDownload:
                                  canDownload ? () => _download(a.path) : null),
                    ),
                ]);
              },
            ),
          ]);
    // 依頼者の動画確認の、画面下のボタン：「修正依頼」「承認する」、その下に「依頼を取り消す」。
    final reviewButtons = Row(children: [
      Expanded(
        flex: 2,
        child: DetailButton('修正依頼', AppColors.white, _busy, () async {
          // 修正の内容は、ダイアログで入力する（問合せと同じ入力ダイアログ。音声入力もできる）。
          final t = await _askText('修正の依頼', '修正してほしい内容を入力（音声でも入力できます）',
              sendLabel: '送信');
          if (t == null) return;
          await _run(
              () => repo.requestRevision(
                  requestId: q.id, uid: widget.uid, instruction: t),
              done: '修正指示を送りました');
        }),
      ),
      SizedBox(width: r.x(10)),
      Expanded(
        flex: 2,
        child: DetailButton('承認する', AppColors.blue, _busy, () async {
          var cleaned = true;
          final ok = await _run(
              () async => cleaned =
                  await repo.approve(requestId: q.id, uid: widget.uid),
              done: '承認しました。編集者へ通知しました');
          if (ok && !cleaned && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content:
                    Text('エラー：添付素材の一部を削除できませんでした。通信を確認して、しばらくしてからお問い合わせください')));
          }
        }),
      ),
      // 幅は 修正依頼：承認する：依頼取消 ＝ 2：2：1。
      if (canCancel) ...[
        SizedBox(width: r.x(10)),
        Expanded(
          flex: 1,
          child: HoldToCancelButton(busy: _busy, onConfirmed: _cancelRequest),
        ),
      ],
    ]);

    final list = ListView(
      padding: EdgeInsets.fromLTRB(r.x(14), r.x(16), r.x(14), r.x(16)),
      children: [
        _noticeBar(),
        if (ownerInquiry)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _answerInquiry(q),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.white,
                  padding: EdgeInsets.symmetric(
                      horizontal: r.x(4), vertical: r.x(6))),
              child: Text('問合せ内容を確認する',
                  style: AppText.dark(r.x(14),
                          weight: FontWeight.w400, height: 21 / 14)
                      .copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.white)),
            ),
          ),
        SizedBox(height: r.x(16)),
        if (!videoLayout) ...[infoCard, SizedBox(height: r.y(10))],
        if (!videoLayout) ...[
          briefCard,
          SizedBox(height: r.y(10)),
          attachCard,
        ],
        SizedBox(height: r.y(10)),
        // 提出された動画は、編集者が初稿を提出した以降（初稿確認・修正・投稿済）の画面にだけ出す。
        // 依頼者の動画確認では、上部のプレーヤーで見るため、ここには出さない。
        if (!videoLayout &&
            (s == RequestStatus.review ||
                s == RequestStatus.revision ||
                s == RequestStatus.posted ||
                // 修正の依頼への問合せ中も、修正を依頼された動画と「！」を見られるようにする。
                (s == RequestStatus.needsInfo && q.inquiryFromRevision)))
          _Submissions(request: q, uid: widget.uid),
        if (!videoLayout && canCancel && !ownerPending && !ownerInquiry) ...[
          SizedBox(height: r.x(16)),
          HoldToCancelButton(busy: _busy, onConfirmed: _cancelRequest),
        ],
      ],
    );
    if (videoLayout) {
      // 依頼者の動画確認：動画の再生エリアを、メッセージとボタンの間いっぱいに広げる（画面を開いたあとに再生）。
      // 基本情報・指示書・添付資料は、右下の資料アイコンから開くダイアログにまとめる。
      return Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(r.x(14), r.x(16), r.x(14), 0),
          child: _noticeBar(),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(r.x(14), r.x(16), r.x(14), r.x(8)),
            child: SubmissionPlayer(
                request: q,
                expand: true,
                onDocs: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => _DocsDialog(children: [
                        infoCard,
                        SizedBox(height: r.y(10)),
                        briefCard,
                        SizedBox(height: r.y(10)),
                        attachCard,
                      ]),
                    )),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(r.x(14), r.x(8), r.x(14), r.x(12)),
          child: reviewing
              ? reviewButtons
              : (canCancel
                  ? HoldToCancelButton(busy: _busy, onConfirmed: _cancelRequest)
                  : const SizedBox.shrink()),
        ),
      ]);
    }
    if (ownerInquiry) {
      return Column(children: [
        Expanded(child: list),
        Padding(
          padding: EdgeInsets.fromLTRB(r.x(14), r.x(8), r.x(14), r.x(12)),
          child: DetailButton(
              '回答する', AppColors.blue, _busy, () => _answerInquiry(q)),
        ),
      ]);
    }
    if (ownerPending) {
      return Column(children: [
        Expanded(child: list),
        Padding(
          padding: EdgeInsets.fromLTRB(r.x(14), r.x(8), r.x(14), r.x(12)),
          child: Row(children: [
            Expanded(
              child:
                  HoldToCancelButton(busy: _busy, onConfirmed: _cancelRequest),
            ),
          ]),
        ),
      ]);
    }
    // 受注した編集者本人の、承認済み：画面下の「投稿完了にする」。
    final post =
        _isEditor && _isAssignee && s == RequestStatus.review && q.approved;
    if (post) {
      return Column(children: [
        Expanded(child: list),
        Padding(
          padding: EdgeInsets.fromLTRB(r.x(14), r.x(8), r.x(14), r.x(12)),
          child: DetailButton(
              '投稿完了にする',
              AppColors.blue,
              _busy,
              () => _run(
                  () => repo.markPosted(requestId: q.id, uid: widget.uid),
                  done: '投稿済にしました')),
        ),
      ]);
    }
    // 受注した編集者本人の、編集中・修正中：画面下の「動画を提出」。
    final submit = _isEditor &&
        _isAssignee &&
        (s == RequestStatus.editing || s == RequestStatus.revision);
    if (submit) {
      return Column(children: [
        Expanded(child: list),
        Padding(
          padding: EdgeInsets.fromLTRB(r.x(14), r.x(8), r.x(14), r.x(12)),
          child: Row(children: [
            // 修正の依頼の内容は、問合せで確認できる（新規依頼の問合せと同じ流れ）。
            if (s == RequestStatus.revision) ...[
              Expanded(
                  child: DetailButton(
                      '問合せ', AppColors.white, _busy, _askRequester)),
              SizedBox(width: r.x(10)),
            ],
            Expanded(
              child:
                  DetailButton('動画を提出', AppColors.blue, _busy, _pickAndSubmit),
            ),
          ]),
        ),
      ]);
    }
    if (!intake && !askMore) return list;
    return Column(children: [
      Expanded(child: list),
      Padding(
        padding: EdgeInsets.fromLTRB(r.x(14), r.x(8), r.x(14), r.x(12)),
        child: Row(children: [
          if (intake) ...[
            Expanded(
              child: DetailButton(
                  '受注',
                  AppColors.blue,
                  _busy,
                  () => _run(
                      () => repo.startEditing(requestId: q.id, uid: widget.uid),
                      done: '受注しました。編集を担当します')),
            ),
            SizedBox(width: r.x(10)),
          ],
          Expanded(
            child: DetailButton('問合せ', AppColors.white, _busy, _askRequester),
          ),
        ]),
      ),
    ]);
  }
}

/// 「問合せ履歴」の行。「履歴を見る」をタップすると、問合せと回答をチャットの形で見られる。
class _InquiryHistoryRow extends StatelessWidget {
  const _InquiryHistoryRow(this.request, {required this.asEditor});
  final VideoRequest request;
  final bool asEditor;

  @override
  Widget build(BuildContext context) => DetailRow('問合せ履歴', '',
      child: Align(
        alignment: Alignment.centerLeft,
        child: TapEditText('履歴を見る',
            label: '問合せ履歴を見る',
            style: AppText.dark(14, weight: FontWeight.w400),
            onTap: (_) => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => InquiryHistoryScreen(
                    request: request, asEditor: asEditor)))),
      ));
}

class _Submissions extends StatelessWidget {
  const _Submissions({required this.request, required this.uid});
  final VideoRequest request;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StaffAccess>(
      stream: Services.repo.watchAccess(uid),
      builder: (context, accessSnap) => _list(context, accessSnap.data),
    );
  }

  Widget _list(BuildContext context, StaffAccess? access) {
    final r = context.r;
    return StreamBuilder<List<Submission>>(
      stream: Services.repo.watchSubmissions(request.id),
      builder: (context, snap) {
        // 承認後は、承認された動画だけが残っている。
        final subs = [
          for (final s in snap.data ?? const <Submission>[])
            if (!request.approved || s.version == request.approvedVersion) s
        ];
        return StreamBuilder<Map<int, String>>(
            stream: Services.repo.watchRevisions(request.id),
            builder: (context, revSnap) {
              final revisions = revSnap.data ?? const <int, String>{};
              return _card(context, r, access, subs, revisions);
            });
      },
    );
  }

  Widget _card(BuildContext context, Responsive r, StaffAccess? access,
      List<Submission> subs, Map<int, String> revisions) {
    {
      {
        return DetailCard(children: [
          Text('提出された動画', style: AppText.dark(r.x(16))),
          if (subs.isEmpty)
            Padding(
                padding: EdgeInsets.only(top: r.y(6)),
                child: Text('まだ提出されていません',
                    style: AppText.dark(r.x(14), weight: FontWeight.w400))),
          for (final s in subs.reversed)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              textColor: AppColors.white,
              iconColor: AppColors.white,
              leading: const Icon(Icons.play_circle_outline),
              title: Text('${s.version == 1 ? '初稿' : '修正動画'}（v${s.version}）',
                  style: AppText.dark(14, weight: FontWeight.w400)),
              subtitle: Text(s.name,
                  style: AppText.dark(12,
                      weight: FontWeight.w400,
                      color: AppColors.white.withValues(alpha: 0.7))),
              // 修正の依頼があった動画には、ダウンロードの左に「！」。完成品のダウンロードは依頼者権限のスタッフだけ。
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                // 承認された動画には、blue の「承認済み」バッジ。題名と動画名の2行分の高さ。
                if (s.version == request.approvedVersion)
                  Container(
                    height: 40,
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text('承認済み',
                        style: AppText.noto(12, color: AppColors.white)),
                  ),
                if ((revisions[s.version] ?? '').isNotEmpty)
                  IconButton(
                    tooltip: '修正の依頼を読む',
                    color: AppColors.amber,
                    icon: const Icon(Icons.warning_amber_rounded),
                    onPressed: () =>
                        _showRevision(context, revisions[s.version]!),
                  ),
                if (access?.canRequest ?? false)
                  Builder(
                    builder: (bctx) => GestureDetector(
                      onLongPress: () =>
                          showSaveMenu(bctx, path: s.path, name: s.name),
                      child: IconButton(
                        tooltip: 'ダウンロード（長押しで保存先を選ぶ）',
                        color: AppColors.white,
                        icon: const Icon(Icons.download),
                        onPressed: () =>
                            saveToDevice(bctx, path: s.path, name: s.name),
                      ),
                    ),
                  ),
              ]),
              onTap: () => showVideoDialog(context,
                  path: s.path, title: '${request.brief.title} v${s.version}'),
            ),
        ]);
      }
    }
  }

  /// 修正の依頼の内容を、ダイアログで読む。
  void _showRevision(BuildContext context, String text) {
    final who = request.requesterName;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        title: Text(who == null ? '修正の依頼' : '$who様からの修正の依頼',
            style: AppText.dark(18)),
        // メッセージの表示エリア：背景は白、文字は ink。
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 280),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: SingleChildScrollView(
            child: Text(text,
                style: AppText.dark(15,
                    weight: FontWeight.w400,
                    height: 1.5,
                    color: AppColors.ink)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child:
                  Text('閉じる', style: AppText.dark(14, color: AppColors.white))),
        ],
      ),
    );
  }
}

/// 中央に置く短い案内（ダーク背景用）。
class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text,
              textAlign: TextAlign.center,
              style: AppText.dark(14, weight: FontWeight.w400)),
        ),
      );
}

/// 依頼の資料（基本情報・指示書・添付資料）をまとめて見るダイアログ。
class _DocsDialog extends StatelessWidget {
  const _DocsDialog({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: AppColors.bg,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: screen.width < 560 ? screen.width : 480,
            maxHeight: screen.height * 0.85),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(children: [
              Expanded(child: Text('依頼の資料', style: AppText.dark(18))),
              IconButton(
                tooltip: '閉じる',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: AppColors.white),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(children: children),
            ),
          ),
        ]),
      ),
    );
  }
}
