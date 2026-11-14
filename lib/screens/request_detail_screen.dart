import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_tokens.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../data/storage_service.dart';
import '../domain/draft.dart';
import '../domain/request_status.dart';
import '../domain/staff_access.dart';
import '../domain/video_request.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_header.dart';
import '../widgets/role_builder.dart';
import '../widgets/status_style.dart';
import '../widgets/video_player_dialog.dart';
import '../widgets/app_icon.dart';
import '../widgets/detail_widgets.dart';
import '../widgets/voice_message_dialog.dart';

/// 案件詳細。依頼者は「動画承認」、編集者は「依頼確認／動画アップロード」を
/// この画面から行う（役割と状態で操作を出し分ける）。
class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      bottomNavigationBar: const AppBottomBar(),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(children: [
          const AppHeader(title: '詳細'),
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
                    return const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.white));
                  }
                  final req = snap.data;
                  if (req == null) {
                    return const _Notice('この案件は見つかりません');
                  }
                  return _Body(request: req, uid: uid, role: role);
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
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  VideoRequest get q => widget.request;
  bool get _isEditor => widget.role == UserRole.editor;

  Future<void> _download(String path) async {
    final url = await Services.repo.downloadUrl(path);
    await launchUrl(Uri.parse(url));
  }

  /// 多重操作を防ぎつつ実行し、失敗は画面に出す。
  Future<void> _run(Future<void> Function() action, {String? done}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('失敗しました：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// メッセージ入力（キーボード／音声）。キャンセルや空なら null。
  Future<String?> _askText(String title, String hint) async {
    final t = await showVoiceMessageDialog(context, title: title, hint: hint);
    return t == null || t.isEmpty ? null : t;
  }

  /// 依頼の取り消し（削除）。確認のあと、承認前の自分の依頼だけ消せる。
  Future<void> _cancelRequest() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(
            side: BorderSide(color: AppColors.white.withValues(alpha: 0.16)),
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('この依頼を取り消しますか？', style: AppText.dark(18)),
        content: Text('取り消すと依頼は削除され、元に戻せません。担当の編集者がいれば通知します。',
            style: AppText.dark(14, weight: FontWeight.w400, height: 1.5)),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.white,
              side: BorderSide(color: AppColors.white.withValues(alpha: 0.55)),
              minimumSize: const Size(96, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: const Text('いいえ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: AppColors.ink,
              minimumSize: const Size(96, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: const Text('取り消す'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
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

  /// 画面上部のお知らせ。状態を語句で伝える。
  String _notice() {
    switch (q.status) {
      case RequestStatus.pending:
        return _isEditor
            ? '新しい依頼です。内容を確認して、編集を開始してください。'
            : '依頼済みです。編集者の受付を待っています。';
      case RequestStatus.needsInfo:
        return q.reviewReason == null
            ? '要確認：編集者から確認があります。'
            : '要確認：${q.reviewReason}';
      case RequestStatus.editing:
        return '編集中です。';
      case RequestStatus.review:
        if (q.approved) return '承認済みです。編集者の投稿を待っています。';
        return _isEditor ? '提出済みです。依頼者の確認を待っています。' : '編集者よりアップされた動画を確認してください。';
      case RequestStatus.revision:
        return q.revisionNote == null
            ? '修正の依頼があります。'
            : '修正の依頼：${q.revisionNote}';
      case RequestStatus.posted:
        return '投稿済みです。';
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final repo = Services.repo;
    final s = q.status;
    final actions = <Widget>[];

    if (_isEditor) {
      if (s == RequestStatus.editing || s == RequestStatus.revision) {
        actions.add(DetailButton(
            s == RequestStatus.revision ? '修正動画を提出' : '初稿動画を提出',
            AppColors.blue,
            _busy,
            _pickAndSubmit));
        if (s == RequestStatus.editing) {
          actions.add(DetailButton('要確認にする', AppColors.amber, _busy, () async {
            final reason = await _askText('確認したい内容', '不明点・確認事項');
            if (reason == null) return;
            await _run(
                () => repo.askForInfo(
                    requestId: q.id, uid: widget.uid, reason: reason),
                done: '依頼者へ差し戻しました');
          }));
        }
      }
      if (s == RequestStatus.review && q.approved) {
        actions.add(DetailButton(
            '投稿完了にする',
            AppColors.blue,
            _busy,
            () => _run(() => repo.markPosted(requestId: q.id, uid: widget.uid),
                done: '投稿済にしました')));
      }
    } else {
      if (s == RequestStatus.needsInfo) {
        actions.add(DetailButton('指示書を修正して再送信', AppColors.amber, _busy, () {
          final d = RequestDraft(requestId: q.id)
            ..brief = q.brief
            ..dueDate = q.dueDate
            ..original = q;
          Navigator.of(context).pushNamed('/chat', arguments: d);
        }));
      }
    }

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

    // 編集者の受付待ちの依頼：画面下の「編集開始」「内容確認」。
    final intake = _isEditor && s == RequestStatus.pending;

    // 依頼者の動画確認（承認／修正依頼）。Figma の「修正の依頼」欄とボタン2つ。
    final reviewing = !_isEditor && s == RequestStatus.review && !q.approved;

    final list = ListView(
      padding: EdgeInsets.fromLTRB(r.x(14), r.x(16), r.x(14), r.x(16)),
      children: [
        NoticeBar(_notice()),
        SizedBox(height: r.x(16)),
        Text(q.brief.title, style: AppText.dark(r.x(20), height: 1.5)),
        SizedBox(height: r.x(10)),
        DetailCard(children: [
          InfoRow('納期', dateText(q.dueDate)),
          InfoRow('長さ', length),
          InfoRow('担当', editorLabel),
          InfoRow('用途', q.brief.platform.isEmpty ? '未設定' : q.brief.platform),
        ]),
        if (reviewing) ...[
          SizedBox(height: r.x(16)),
          Text('修正の依頼', style: AppText.dark(r.x(16), height: 26 / 16)),
          SizedBox(height: r.x(6)),
          TextField(
            controller: _note,
            minLines: 8,
            maxLines: 8,
            enabled: !_busy,
            style:
                AppText.dark(r.x(14), weight: FontWeight.w400, height: 20 / 14),
            cursorColor: AppColors.white,
            decoration: InputDecoration(
              hintText: '修正してほしい内容を入力',
              hintStyle: AppText.dark(r.x(14),
                  weight: FontWeight.w400,
                  color: AppColors.white.withValues(alpha: 0.7)),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: r.x(12), vertical: r.x(10)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                      color: AppColors.white.withValues(alpha: 0.55))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.white)),
            ),
          ),
          SizedBox(height: r.x(20)),
          Row(children: [
            Expanded(
              child: DetailButton('修正依頼', AppColors.white, _busy, () async {
                final t = _note.text.trim();
                if (t.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('エラー：修正してほしい内容を入力してください')));
                  return;
                }
                await _run(
                    () => repo.requestRevision(
                        requestId: q.id, uid: widget.uid, instruction: t),
                    done: '修正指示を送りました');
              }),
            ),
            SizedBox(width: r.x(10)),
            Expanded(
              child: DetailButton(
                  '承認する',
                  AppColors.blue,
                  _busy,
                  () => _run(
                      () => repo.approve(requestId: q.id, uid: widget.uid),
                      done: '承認しました。編集者へ通知しました')),
            ),
          ]),
        ],
        if (actions.isNotEmpty) ...[
          SizedBox(height: r.y(16)),
          for (final a in actions)
            Padding(padding: EdgeInsets.only(bottom: r.y(8)), child: a),
        ],
        SizedBox(height: r.y(10)),
        DetailCard(children: [
          Text('指示書', style: AppText.dark(r.x(16))),
          if (q.brief.videoType.isNotEmpty)
            DetailRow('動画の種類', q.brief.videoType),
          if (q.brief.platform.isNotEmpty) DetailRow('投稿先', q.brief.platform),
          if (q.brief.audience.isNotEmpty) DetailRow('視聴者', q.brief.audience),
          DetailRow('目的', q.brief.purpose),
          if (q.brief.structure.isNotEmpty) DetailRow('構成', q.brief.structure),
          DetailRow('納品条件', q.brief.deliveryTerms),
          for (var i = 0; i < q.brief.scenes.length; i++)
            DetailRow('場面${i + 1}',
                '${q.brief.scenes[i].title}\n${q.brief.scenes[i].instruction}'),
        ]),
        SizedBox(height: r.y(10)),
        DetailCard(children: [
          Text('添付資料', style: AppText.dark(r.x(16))),
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
                    leading: a.kind == 'video'
                        ? const Icon(Icons.play_circle_outline)
                        : const AppIcon(AppIcons.attachFile,
                            size: 24, color: AppColors.white),
                    title: Text(a.name),
                    subtitle: !canDownload && a.kind != 'video'
                        ? Text('ダウンロードは編集者のみ',
                            style: TextStyle(
                                color: AppColors.white.withValues(alpha: 0.7)))
                        : null,
                    trailing: canDownload
                        ? IconButton(
                            tooltip: 'ダウンロード',
                            color: AppColors.white,
                            icon: const Icon(Icons.download),
                            onPressed: () => _download(a.path),
                          )
                        : null,
                    onTap: () async {
                      if (a.kind == 'video') {
                        await showVideoDialog(context,
                            path: a.path, title: a.name);
                      } else if (canDownload) {
                        await _download(a.path);
                      }
                    },
                  ),
              ]);
            },
          ),
        ]),
        SizedBox(height: r.y(10)),
        _Submissions(request: q, uid: widget.uid),
        if (canCancel) ...[
          SizedBox(height: r.x(16)),
          DetailButton('依頼を取り消す', AppColors.amber, _busy, _cancelRequest),
        ],
      ],
    );
    if (!intake) return list;
    return Column(children: [
      Expanded(child: list),
      Padding(
        padding: EdgeInsets.fromLTRB(r.x(14), r.x(8), r.x(14), r.x(12)),
        child: Row(children: [
          Expanded(
            child: DetailButton(
                '編集開始',
                AppColors.blue,
                _busy,
                () => _run(
                    () => repo.startEditing(requestId: q.id, uid: widget.uid),
                    done: '編集を開始しました')),
          ),
          SizedBox(width: r.x(10)),
          Expanded(
            child: DetailButton('内容確認', AppColors.white, _busy, () async {
              final message =
                  await _askText('依頼者へのメッセージ', '確認したい内容を入力（音声でも入力できます）');
              if (message == null) return;
              await _run(
                  () => repo.askForInfo(
                      requestId: q.id, uid: widget.uid, reason: message),
                  done: '依頼者へ通知しました');
            }),
          ),
        ]),
      ),
    ]);
  }
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
        final subs = snap.data ?? const <Submission>[];
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
              title: Text(
                  '${s.version == 1 ? '初稿' : '修正動画'}（v${s.version}）${s.version == request.approvedVersion ? '　承認済み' : ''}'),
              subtitle: Text(s.name,
                  style:
                      TextStyle(color: AppColors.white.withValues(alpha: 0.7))),
              // 完成品のダウンロードは依頼者権限のスタッフだけ。
              trailing: (access?.canRequest ?? false)
                  ? IconButton(
                      tooltip: 'ダウンロード',
                      color: AppColors.white,
                      icon: const Icon(Icons.download),
                      onPressed: () async {
                        final url = await Services.repo.downloadUrl(s.path);
                        await launchUrl(Uri.parse(url));
                      },
                    )
                  : null,
              onTap: () => showVideoDialog(context,
                  path: s.path, title: '${request.brief.title} v${s.version}'),
            ),
        ]);
      },
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
