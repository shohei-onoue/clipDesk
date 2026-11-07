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
  bool _sending = false;
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
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } catch (e) {
      // 失敗時は送信済みにならない。同じ画面から再試行できる（同じ依頼IDで冪等）。
      if (mounted) setState(() => _error = '送信に失敗しました。もう一度お試しください。\n$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final d = ModalRoute.of(context)!.settings.arguments as RequestDraft;
    final errors = d.validate(DateTime.now());
    final b = d.brief;
    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: '指示書確認'),
            Expanded(
              child: ColoredBox(
                color: Colors.white,
                child: BottomAlignedScroll(
                  children: [
                    AssistantMessage(
                      fixedWidth: true,
                      lines: [
                        '依頼内容のまとめ',
                        '依頼名：${b.title}',
                        if (b.videoType.isNotEmpty) '動画の種類：${b.videoType}',
                        if (b.platform.isNotEmpty) '投稿先：${b.platform}',
                        if (b.audience.isNotEmpty) '視聴者：${b.audience}',
                        '目的：${b.purpose}',
                        '構成：${b.structure}',
                        '納品条件：${b.deliveryTerms}',
                        if (d.original == null) ...[
                          '動画：${d.videos.map((f) => f.name).join('、')}',
                          '参考資料：${d.references.isEmpty ? 'なし' : d.references.map((f) => f.name).join('、')}',
                        ] else
                          '添付：${d.original!.attachments.map((a) => a.name).join('、')}（変更なし）',
                        '希望納期：${dateText(d.dueDate)}',
                        '場面：${b.scenes.isEmpty ? 'なし' : '${b.scenes.length} つ'}',
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
              color: Colors.white,
              padding: EdgeInsets.all(r.x(5)),
              child: Row(
                children: [
                  Expanded(
                    child: _Button('修正する', Colors.white, AppColors.ink,
                        _sending ? null : () => Navigator.of(context).pop()),
                  ),
                  SizedBox(width: r.x(8)),
                  Expanded(
                    child: _Button(
                      _sending
                          ? '送信中…'
                          : (d.original != null ? '再送信する' : '依頼する'),
                      AppColors.amber,
                      Colors.white,
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
      color: onTap == null ? Colors.grey.shade400 : bg,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.ink),
        borderRadius: BorderRadius.circular(r.x(20)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(r.x(20)),
        onTap: onTap,
        child: SizedBox(
          height: r.y(66),
          child: Center(
            child: Text(label,
                style: AppText.noto(r.x(16),
                    color: onTap == null ? Colors.white : fg,
                    height: 20.8 / 16)),
          ),
        ),
      ),
    );
  }
}
