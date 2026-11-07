import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../data/storage_service.dart';
import '../domain/draft.dart';
import '../domain/request_status.dart';
import '../domain/video_request.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/role_builder.dart';
import '../widgets/status_style.dart';
import '../widgets/video_player_dialog.dart';

/// 案件詳細。依頼者は「動画承認」、編集者は「依頼確認／動画アップロード」を
/// この画面から行う（役割と状態で操作を出し分ける）。
class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(children: [
          const AppHeader(title: '案件詳細', background: AppColors.bg),
          Expanded(
            child: RoleBuilder(
              builder: (context, uid, role) => StreamBuilder<VideoRequest?>(
                stream: Services.repo.watchRequest(requestId),
                builder: (context, snap) {
                  if (snap.hasError) {
                    // 権限のない案件は読み取りが拒否される。
                    return const Center(child: Text('この案件を表示できません'));
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final req = snap.data;
                  if (req == null) {
                    return const Center(child: Text('案件が見つかりません'));
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

  VideoRequest get q => widget.request;
  bool get _isEditor => widget.role == UserRole.editor;

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

  Future<String?> _askText(String title, String hint) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
            controller: c,
            autofocus: true,
            maxLines: 4,
            decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('送信')),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final repo = Services.repo;
    final s = q.status;
    final actions = <Widget>[];

    if (_isEditor) {
      if (s == RequestStatus.pending) {
        actions.addAll([
          _Btn(
              '編集を開始',
              AppColors.blue,
              _busy,
              () => _run(
                  () => repo.startEditing(requestId: q.id, uid: widget.uid),
                  done: '編集を開始しました')),
          _Btn('要確認にする（理由を添えて差し戻し）', AppColors.amber, _busy, () async {
            final reason = await _askText('確認したい内容', '不明点・確認事項');
            if (reason == null) return;
            await _run(
                () => repo.askForInfo(
                    requestId: q.id, uid: widget.uid, reason: reason),
                done: '依頼者へ差し戻しました');
          }),
        ]);
      }
      if (s == RequestStatus.editing || s == RequestStatus.revision) {
        actions.add(_Btn(s == RequestStatus.revision ? '修正動画を提出' : '初稿動画を提出',
            AppColors.blue, _busy, _pickAndSubmit));
        if (s == RequestStatus.editing) {
          actions.add(_Btn('要確認にする', AppColors.amber, _busy, () async {
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
        actions.add(_Btn(
            '投稿完了にする',
            AppColors.blue,
            _busy,
            () => _run(() => repo.markPosted(requestId: q.id, uid: widget.uid),
                done: '投稿済にしました')));
      }
    } else {
      if (s == RequestStatus.needsInfo) {
        actions.add(_Btn('指示書を修正して再送信', AppColors.amber, _busy, () {
          final d = RequestDraft(requestId: q.id)
            ..brief = q.brief
            ..dueDate = q.dueDate
            ..original = q;
          Navigator.of(context).pushNamed('/chat', arguments: d);
        }));
      }
      if (s == RequestStatus.review && !q.approved) {
        actions.addAll([
          _Btn(
              '承認する',
              AppColors.blue,
              _busy,
              () => _run(() => repo.approve(requestId: q.id, uid: widget.uid),
                  done: '承認しました。編集者へ通知しました')),
          _Btn('修正を依頼', AppColors.amber, _busy, () async {
            final t = await _askText('修正指示', '直してほしい点');
            if (t == null) return;
            await _run(
                () => repo.requestRevision(
                    requestId: q.id, uid: widget.uid, instruction: t),
                done: '修正指示を送りました');
          }),
        ]);
      }
    }

    return ListView(
      padding: EdgeInsets.all(r.x(10)),
      children: [
        _Card(children: [
          Text(q.brief.title, style: AppText.noto(r.x(20), height: 1.5)),
          _Row('進捗', q.statusLabel),
          _Row('納期', dateText(q.dueDate)),
          if (q.status == RequestStatus.needsInfo && q.reviewReason != null)
            _Row('確認事項', q.reviewReason!),
          if (q.status == RequestStatus.revision && q.revisionNote != null)
            _Row('修正指示', q.revisionNote!),
          if (q.status == RequestStatus.review && q.approved)
            _Row('承認', '承認済み。編集者の投稿を待っています'),
        ]),
        if (actions.isNotEmpty) ...[
          SizedBox(height: r.y(10)),
          for (final a in actions)
            Padding(padding: EdgeInsets.only(bottom: r.y(8)), child: a),
        ],
        SizedBox(height: r.y(10)),
        _Card(children: [
          Text('指示書', style: AppText.noto(r.x(16))),
          if (q.brief.videoType.isNotEmpty) _Row('動画の種類', q.brief.videoType),
          if (q.brief.platform.isNotEmpty) _Row('投稿先', q.brief.platform),
          if (q.brief.audience.isNotEmpty) _Row('視聴者', q.brief.audience),
          _Row('目的', q.brief.purpose),
          _Row('構成', q.brief.structure),
          _Row('納品条件', q.brief.deliveryTerms),
          for (var i = 0; i < q.brief.scenes.length; i++)
            _Row('場面${i + 1}',
                '${q.brief.scenes[i].title}\n${q.brief.scenes[i].instruction}'),
        ]),
        SizedBox(height: r.y(10)),
        _Card(children: [
          Text('添付資料', style: AppText.noto(r.x(16))),
          for (final a in q.attachments)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(a.kind == 'video'
                  ? Icons.play_circle_outline
                  : Icons.attach_file),
              title: Text(a.name),
              onTap: () async {
                if (a.kind == 'video') {
                  await showVideoDialog(context, path: a.path, title: a.name);
                } else {
                  final url = await Services.repo.downloadUrl(a.path);
                  await launchUrl(Uri.parse(url));
                }
              },
            ),
        ]),
        SizedBox(height: r.y(10)),
        _Submissions(request: q),
      ],
    );
  }
}

class _Submissions extends StatelessWidget {
  const _Submissions({required this.request});
  final VideoRequest request;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return StreamBuilder<List<Submission>>(
      stream: Services.repo.watchSubmissions(request.id),
      builder: (context, snap) {
        final subs = snap.data ?? const <Submission>[];
        return _Card(children: [
          Text('提出された動画', style: AppText.noto(r.x(16))),
          if (subs.isEmpty) const Text('まだ提出されていません'),
          for (final s in subs.reversed)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_circle_outline),
              title: Text(
                  '${s.version == 1 ? '初稿' : '修正動画'}（v${s.version}）${s.version == request.approvedVersion ? '　承認済み' : ''}'),
              subtitle: Text(s.name),
              onTap: () => showVideoDialog(context,
                  path: s.path, title: '${request.brief.title} v${s.version}'),
            ),
        ]);
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.x(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.ink),
        borderRadius: BorderRadius.circular(r.x(16)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.only(top: r.y(6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: r.x(80),
              child: Text(label,
                  style: AppText.noto(r.x(14), color: AppColors.stepGrey))),
          Expanded(
              child: Text(value,
                  style: AppText.noto(r.x(14), weight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, this.color, this.busy, this.onTap);
  final String label;
  final Color color;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Material(
      color: busy ? Colors.grey : color,
      borderRadius: BorderRadius.circular(r.x(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(r.x(20)),
        onTap: busy ? null : onTap,
        child: SizedBox(
          height: r.y(56),
          width: double.infinity,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(label,
                    style: AppText.noto(r.x(16), color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
