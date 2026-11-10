import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/request_status.dart';
import '../domain/video_request.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_header.dart';
import '../widgets/list_helpers.dart';
import '../widgets/request_card.dart';
import '../widgets/role_builder.dart';
import '../widgets/video_player_dialog.dart';

/// 納品ライブラリ: 投稿済の依頼の最終動画（承認された版）を確認する。
/// 閲覧範囲は未確定のため、依頼者本人と担当編集者のみ（暫定）。
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
          const AppHeader(title: '納品ライブラリ'),
          Expanded(
            child: RoleBuilder(
              dark: true,
              builder: (context, uid, role) =>
                  StreamBuilder<List<VideoRequest>>(
                stream: role == UserRole.editor
                    ? Services.repo.watchEditor(uid)
                    : Services.repo.watchRequester(uid),
                builder: (context, snap) {
                  final posted = [
                    for (final q in snap.data ?? const <VideoRequest>[])
                      if (q.status == RequestStatus.posted) q
                  ];
                  return ListView(
                    padding: EdgeInsets.all(r.x(10)),
                    children: [
                      if (snap.hasError)
                        emptyTextDark(context,
                            'エラー：読み込みに失敗しました（${snap.error}）。通信を確認して、もう一度開いてください')
                      else if (posted.isEmpty &&
                          snap.connectionState != ConnectionState.waiting)
                        emptyTextDark(context, '投稿済の動画はまだありません'),
                      for (final q in posted)
                        Padding(
                          padding: EdgeInsets.only(bottom: r.y(10)),
                          child: _Item(request: q),
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

class _Item extends StatelessWidget {
  const _Item({required this.request});
  final VideoRequest request;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Submission>>(
      stream: Services.repo.watchSubmissions(request.id),
      builder: (context, snap) {
        final subs = snap.data ?? const <Submission>[];
        final final_ = subs.where((s) => s.version == request.approvedVersion);
        return RequestCard(
          progress: 1,
          progressLabel: '完了',
          title: request.brief.title,
          meta: final_.isEmpty ? '最終動画を読み込み中' : '最終動画を再生',
          tag: '投稿済',
          onTap: final_.isEmpty
              ? () => openRequest(context, request.id)
              : () => showVideoDialog(context,
                  path: final_.first.path, title: request.brief.title),
        );
      },
    );
  }
}
