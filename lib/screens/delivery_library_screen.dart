import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/request_status.dart';
import '../domain/video_request.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/list_helpers.dart';
import '../widgets/role_builder.dart';
import '../widgets/video_player_dialog.dart';

/// ライブラリ（Figma 302:7489）：過去に承認された編集完了動画の一覧。
/// 1本ずつカードにして縦に並べる。閲覧範囲は未確定のため、依頼者本人と担当編集者のみ（暫定）。
class DeliveryLibraryScreen extends StatelessWidget {
  const DeliveryLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: AppColors.ink,
      bottomNavigationBar: const AppBottomBar(),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(children: [
          const AppHeader(title: 'ライブラリ'),
          Expanded(
            child: RoleBuilder(
              dark: true,
              builder: (context, uid, role) =>
                  StreamBuilder<List<VideoRequest>>(
                stream: role == UserRole.editor
                    ? Services.repo.watchEditor(uid)
                    : Services.repo.watchRequester(uid),
                builder: (context, snap) {
                  // 承認された動画（承認済みの確認待ち・投稿済み）を、承認が新しい順に。
                  final approved = [
                    for (final q in snap.data ?? const <VideoRequest>[])
                      if (q.approved) q
                  ]..sort((a, b) => (b.approvedAt ?? DateTime(0))
                      .compareTo(a.approvedAt ?? DateTime(0)));
                  return ListView(
                    padding:
                        EdgeInsets.fromLTRB(r.x(14), r.x(16), r.x(14), r.x(16)),
                    children: [
                      if (snap.hasError)
                        emptyTextDark(context,
                            'エラー：読み込みに失敗しました（${snap.error}）。通信を確認して、もう一度開いてください')
                      else if (approved.isEmpty &&
                          snap.connectionState != ConnectionState.waiting)
                        emptyTextDark(context, '承認された動画はまだありません'),
                      for (final q in approved)
                        Padding(
                          padding: EdgeInsets.only(bottom: r.x(12)),
                          child: _LibraryCard(request: q),
                        ),
                    ],
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

String _dateTime(DateTime? t) {
  if (t == null) return '承認日時 未記録';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}/${two(t.month)}/${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// 動画1本分のカード：左に再生サムネイル、右に題名・承認日時・編集者名。
class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.request});
  final VideoRequest request;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return StreamBuilder<List<Submission>>(
      stream: Services.repo.watchSubmissions(request.id),
      builder: (context, snap) {
        final subs = snap.data ?? const <Submission>[];
        final video =
            subs.where((s) => s.version == request.approvedVersion).firstOrNull;
        return Semantics(
          button: true,
          label: '${request.brief.title}を再生する',
          child: GestureDetector(
            onTap: video == null
                ? () => openRequest(context, request.id)
                : () => showVideoDialog(context,
                    path: video.path, title: request.brief.title),
            child: Container(
              padding: EdgeInsets.all(r.x(9)),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.08),
                border:
                    Border.all(color: AppColors.white.withValues(alpha: 0.16)),
                borderRadius: BorderRadius.circular(r.x(15)),
              ),
              child: Row(children: [
                Container(
                  width: r.x(87),
                  height: r.x(81),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(r.x(10)),
                  ),
                  child: Icon(Icons.play_arrow,
                      size: r.x(32), color: AppColors.white),
                ),
                SizedBox(width: r.x(16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.brief.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.dark(r.x(16),
                              weight: FontWeight.w400, height: 20 / 16)),
                      SizedBox(height: r.x(12)),
                      Text(_dateTime(request.approvedAt),
                          style: AppText.dark(r.x(14),
                              weight: FontWeight.w400, height: 20 / 14)),
                      _EditorName(request.editorId, request.editorName),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

/// 編集者名。名前を読む権限がないときは「担当 決定済」と出す。
class _EditorName extends StatelessWidget {
  const _EditorName(this.editorId, this.savedName);
  final String? editorId;

  /// 案件に残した編集者名。古い依頼では null で、そのときはプロフィールから読む。
  final String? savedName;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final id = editorId;
    return FutureBuilder<String?>(
      future: id == null || savedName != null
          ? Future.value(savedName)
          : Services.repo.userName(id),
      builder: (context, snap) => Text(
          id == null ? '編集者 未定' : (snap.data ?? '編集者 決定済'),
          style:
              AppText.dark(r.x(14), weight: FontWeight.w400, height: 20 / 14)),
    );
  }
}
