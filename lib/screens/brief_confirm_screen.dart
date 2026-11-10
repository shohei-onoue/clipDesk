import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/draft.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/status_style.dart';

/// 04 指示書確認。入力した実データを表示し、修正に戻る／送信できる。
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
      Navigator.of(context).pushNamedAndRemoveUntil('/requester', (_) => false);
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
    return Scaffold(
      backgroundColor: AppColors.ink,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: '指示書確認'),
            Expanded(
              child: ColoredBox(
                color: AppColors.ink,
                child: BottomAlignedScroll(
                  alignTop: true,
                  children: [
                    AssistantMessage(
                      fixedWidth: true,
                      lines: [
                        '以下の内容で依頼します。',
                        '依頼名：${b.title}',
                        if (b.videoType.isNotEmpty) '動画の種類：${b.videoType}',
                        if (b.platform.isNotEmpty) '投稿先：${b.platform}',
                        if (b.audience.isNotEmpty) '視聴者：${b.audience}',
                        '目的：${b.purpose}',
                        if (b.structure.isNotEmpty) '構成：${b.structure}',
                        ..._delivery(b.deliveryTerms),
                        '希望納期：${dateText(d.dueDate)}',
                        if (d.original == null) ...[
                          '動画：${d.videos.isEmpty ? 'なし' : d.videos.map((f) => f.name).join('、')}',
                          '画像・その他の添付：${d.references.isEmpty ? 'なし' : d.references.map((f) => f.name).join('、')}',
                        ] else
                          '添付：${d.original!.attachments.map((a) => a.name).join('、')}（変更なし）',
                        if (b.scenes.isNotEmpty) '場面：${b.scenes.length} つ',
                        for (var i = 0; i < b.scenes.length; i++)
                          '　${i + 1}. ${b.scenes[i].title}：${b.scenes[i].instruction}',
                      ],
                    ),
                    if (errors.isNotEmpty)
                      AssistantMessage(
                        showHeader: false,
                        fixedWidth: true,
                        lines: [
                          '次の項目を直してください',
                          ...errors.values.map((e) => '・$e'),
                        ],
                      ),
                    if (_error != null)
                      AssistantMessage(
                          showHeader: false, fixedWidth: true, text: _error!),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.08),
                border: Border(
                    top: BorderSide(
                        color: AppColors.white.withValues(alpha: 0.16))),
              ),
              padding: EdgeInsets.all(r.x(5)),
              child: Row(
                children: [
                  Expanded(
                    child: _Button(
                        '修正する',
                        AppColors.white.withValues(alpha: 0.08),
                        AppColors.white,
                        _sending ? null : () => Navigator.of(context).pop()),
                  ),
                  SizedBox(width: r.x(8)),
                  Expanded(
                    child: _Button(
                      _sending
                          ? (_progress.isEmpty ? '送信中…' : '送信中 $_progress')
                          : (d.original != null ? '再送信する' : '依頼する'),
                      AppColors.amber,
                      AppColors.ink,
                      (_sending || errors.isNotEmpty) ? null : () => _submit(d),
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

class _Button extends StatelessWidget {
  const _Button(this.label, this.bg, this.fg, this.onTap);
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Material(
      color: onTap == null ? AppColors.white.withValues(alpha: 0.16) : bg,
      shape: RoundedRectangleBorder(
        side: BorderSide(
            color: onTap == null
                ? AppColors.white.withValues(alpha: 0.16)
                : AppColors.white.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(r.x(15)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(r.x(15)),
        onTap: onTap,
        child: SizedBox(
          height: r.y(66),
          child: Center(
            child: Text(label,
                style: AppText.noto(r.x(16),
                    color: onTap == null
                        ? AppColors.white.withValues(alpha: 0.7)
                        : fg,
                    height: 20.8 / 16)),
          ),
        ),
      ),
    );
  }
}
