import 'dart:typed_data';

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
import '../widgets/detail_widgets.dart';
import '../widgets/status_style.dart';

/// 04 指示書確認。案件詳細と同じ「詳細」のレイアウトで、入力した内容と添付ファイルを確認し、修正に戻る／送信できる。
class BriefConfirmScreen extends StatefulWidget {
  const BriefConfirmScreen({super.key});

  @override
  State<BriefConfirmScreen> createState() => _BriefConfirmScreenState();
}

class _BriefConfirmScreenState extends State<BriefConfirmScreen> {
  /// 納品条件（「30秒・縦型・字幕あり」）を、長さ・向き・字幕のラベルつきに分ける。
  /// 形式が違う（過去の依頼）ときは、そのまま「納品条件」として出す。
  List<String> _delivery(String terms) {
    final parts = terms.split('・');
    if (parts.length == 3 && parts[2].startsWith('字幕')) {
      return [
        '動画の長さ：${parts[0]}',
        '画面の向き：${parts[1]}',
        '字幕：${parts[2].substring(2)}',
      ];
    }
    return ['納品条件：$terms'];
  }

  bool _sending = false;

  /// 添付のアップロード状況（完了数 / 全体）。
  String _progress = '';
  String? _error;

  Future<void> _submit(RequestDraft d) async {
    if (_sending) return; // 多重送信の防止
    final uid = Services.uid;
    if (uid == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      if (d.original != null) {
        await Services.repo.resubmitBrief(
            requestId: d.requestId,
            uid: uid,
            brief: d.brief,
            dueDate: d.dueDate!);
      } else {
        await Services.repo.createRequest(
          requestId: d.requestId,
          requesterId: uid,
          brief: d.brief,
          dueDate: d.dueDate!,
          videos: d.videos,
          references: d.references,
          onProgress: (done, total) {
            if (mounted) setState(() => _progress = '$done/$total');
          },
        );
      }
      if (!mounted) return;
      // 依頼が済んだら、ダッシュボード（/home）へ。戻るとメイン画面に戻る。
      Navigator.of(context).pushNamedAndRemoveUntil(
          '/home', (route) => route.settings.name == '/menu');
    } catch (e) {
      // 失敗時は送信済みにならない。同じ画面から再試行できる（同じ依頼IDで冪等）。
      if (mounted) {
        setState(
            () => _error = 'エラー：依頼を送信できませんでした。通信を確認して、もう一度「依頼する」を押してください。\n$e');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! RequestDraft) {
      // ブラウザの再読み込みなどで、入力中の内容が失われたとき。
      return Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          child: Column(children: [
            const AppHeader(title: '指示書確認'),
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(r.x(24)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('エラー：入力中の内容が見つかりません。メインに戻って、もう一度依頼を作成してください。',
                          textAlign: TextAlign.center,
                          style: AppText.dark(16,
                              weight: FontWeight.w400, height: 1.6)),
                      SizedBox(height: r.y(16)),
                      FilledButton(
                        onPressed: () => Navigator.of(context)
                            .pushNamedAndRemoveUntil('/menu', (_) => false),
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.blue,
                            foregroundColor: AppColors.white),
                        child: const Text('メインに戻る'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
    }
    final d = args;
    final errors = d.validate(DateTime.now());
    final b = d.brief;
    // 納品条件の先頭が長さ（例：「30秒・縦型・字幕あり」）。
    final length =
        b.deliveryTerms.isEmpty ? '未設定' : b.deliveryTerms.split('・').first;
    // 添付は、動画（編集する動画）→ 参考資料の順に並べる。再送信時は元の添付（変更なし）。
    final files = d.original != null
        ? [
            for (final a in d.original!.attachments)
              (
                name: a.name,
                size: a.size,
                video: a.kind == 'video',
                file: null as UploadFile?
              )
          ]
        : [
            for (final f in d.videos)
              (name: f.name, size: f.size, video: true, file: f as UploadFile?),
            for (final f in d.references)
              (
                name: f.name,
                size: f.size,
                video: false,
                file: f as UploadFile?
              ),
          ];
    return Scaffold(
      backgroundColor: AppColors.ink,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: '詳細'),
            Expanded(
              child: ListView(
                padding:
                    EdgeInsets.fromLTRB(r.x(14), r.x(16), r.x(14), r.x(16)),
                children: [
                  NoticeBar(d.original != null
                      ? '内容を確認して、「再送信する」を押してください。'
                      : '内容と添付ファイルを確認して、「依頼する」を押してください。'),
                  SizedBox(height: r.x(16)),
                  Text(b.title.isEmpty ? '（題名なし）' : b.title,
                      style: AppText.dark(r.x(20), height: 1.5)),
                  SizedBox(height: r.x(10)),
                  DetailCard(children: [
                    InfoRow('納期', dateText(d.dueDate)),
                    InfoRow('長さ', length),
                    const InfoRow('担当', '未定'),
                    InfoRow('用途', b.platform.isEmpty ? '未設定' : b.platform),
                  ]),
                  if (errors.isNotEmpty) ...[
                    SizedBox(height: r.x(12)),
                    DetailCard(children: [
                      Text('要確認：次の項目を直してください', style: AppText.dark(r.x(14))),
                      for (final e in errors.values) DetailRow('・', e),
                    ]),
                  ],
                  SizedBox(height: r.x(12)),
                  DetailCard(children: [
                    Text('指示書', style: AppText.dark(r.x(16))),
                    if (b.videoType.isNotEmpty) DetailRow('動画の種類', b.videoType),
                    if (b.platform.isNotEmpty) DetailRow('投稿先', b.platform),
                    if (b.audience.isNotEmpty) DetailRow('視聴者', b.audience),
                    DetailRow('目的', b.purpose),
                    if (b.structure.isNotEmpty) DetailRow('構成', b.structure),
                    for (final line in _delivery(b.deliveryTerms))
                      DetailRow(
                          line.split('：').first,
                          line.contains('：')
                              ? line.split('：').skip(1).join('：')
                              : ''),
                    for (var i = 0; i < b.scenes.length; i++)
                      DetailRow('場面${i + 1}',
                          '${b.scenes[i].title}\n${b.scenes[i].instruction}'),
                  ]),
                  SizedBox(height: r.x(12)),
                  DetailCard(children: [
                    Text('添付ファイル（${files.length}件）',
                        style: AppText.dark(r.x(16))),
                    if (files.isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: r.x(6)),
                        child: Text('添付はありません',
                            style:
                                AppText.dark(r.x(14), weight: FontWeight.w400)),
                      ),
                    for (final f in files)
                      _AttachmentTile(
                          name: f.name,
                          size: f.size,
                          video: f.video,
                          file: f.file),
                    if (d.original != null)
                      Padding(
                        padding: EdgeInsets.only(top: r.x(6)),
                        child: Text('再送信では添付は変わりません',
                            style: AppText.dark(r.x(12),
                                weight: FontWeight.w400,
                                color: AppColors.white.withValues(alpha: 0.7))),
                      ),
                  ]),
                  if (_error != null) ...[
                    SizedBox(height: r.x(12)),
                    DetailCard(children: [
                      Text(_error!,
                          style: AppText.dark(r.x(14),
                              weight: FontWeight.w400, height: 1.5)),
                    ]),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(r.x(14), r.x(8), r.x(14), r.x(12)),
              child: Row(
                children: [
                  Expanded(
                    child: DetailButton('修正する', AppColors.white, false,
                        () => Navigator.of(context).pop(),
                        disabled: _sending),
                  ),
                  SizedBox(width: r.x(10)),
                  Expanded(
                    child: DetailButton(
                      _sending
                          ? (_progress.isEmpty ? '送信中…' : '送信中 $_progress')
                          : (d.original != null ? '再送信する' : '依頼する'),
                      AppColors.blue,
                      false,
                      () => _submit(d),
                      disabled: _sending || errors.isNotEmpty,
                    ),
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

/// 添付1件分。画像は小さく表示し、動画・その他は名前と大きさで確認する。
class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.name,
    required this.size,
    required this.video,
    required this.file,
  });

  final String name;
  final int size;
  final bool video;

  /// 送信前のファイル（画像のプレビュー用）。再送信時は null。
  final UploadFile? file;

  static bool _isImage(String n) {
    final l = n.toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'].any(l.endsWith);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final kind = video
        ? '動画'
        : _isImage(name)
            ? '画像'
            : name.toLowerCase().endsWith('.mp3')
                ? 'BGM'
                : '資料';
    final mb = (size / 1024 / 1024).toStringAsFixed(1);
    return Padding(
      padding: EdgeInsets.only(top: r.x(8)),
      child: Row(children: [
        Container(
          width: r.x(56),
          height: r.x(56),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: kind == '画像' && file != null
              ? FutureBuilder<Uint8List>(
                  future: file!.read(),
                  builder: (context, snap) => snap.hasData
                      ? Image.memory(snap.data!, fit: BoxFit.cover)
                      : const SizedBox.shrink())
              : Icon(
                  video
                      ? Icons.videocam_outlined
                      : kind == 'BGM'
                          ? Icons.music_note_outlined
                          : Icons.insert_drive_file_outlined,
                  color: AppColors.white),
        ),
        SizedBox(width: r.x(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.dark(r.x(14),
                      weight: FontWeight.w400, height: 20 / 14)),
              Text('$kind・$mb MB',
                  style: AppText.dark(r.x(12),
                      weight: FontWeight.w400,
                      color: AppColors.white.withValues(alpha: 0.7),
                      height: 16 / 12)),
            ],
          ),
        ),
      ]),
    );
  }
}
