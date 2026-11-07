import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/request_status.dart';
import '../domain/video_request.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/filter_chips_row.dart';
import '../widgets/list_helpers.dart';
import '../widgets/role_builder.dart';
import '../widgets/step_progress_card.dart';

/// 進捗状況。自分が関わる動いている案件（依頼した案件＋担当・受付待ちの案件）だけを出し、
/// 受付待ち・要確認・編集中・初稿確認・修正はタブのボタンで絞り込む。投稿済みは出さない。
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  static const _tabs = <RequestStatus?>[
    null,
    RequestStatus.pending,
    RequestStatus.needsInfo,
    RequestStatus.editing,
    RequestStatus.review,
    RequestStatus.revision,
  ];
  static const _labels = ['進行中', '受付待ち', '要確認', '編集中', '初稿確認', '修正'];

  int _tab = 0;
  String? _uid;
  Stream<List<VideoRequest>>? _asRequester;
  Stream<List<VideoRequest>>? _asEditor;

  void _init(String uid) {
    if (_uid == uid) return;
    _uid = uid;
    _asRequester = Services.repo.watchRequester(uid);
    _asEditor = Services.repo.watchEditor(uid);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(children: [
          const AppHeader(title: '進捗状況', background: AppColors.bg),
          Expanded(
            child: RoleBuilder(
              builder: (context, uid, _) {
                _init(uid);
                return StreamBuilder<List<VideoRequest>>(
                  stream: _asRequester,
                  builder: (context, a) => StreamBuilder<List<VideoRequest>>(
                    stream: _asEditor,
                    builder: (context, b) {
                      final error = a.error ?? b.error;
                      final waiting = !a.hasData && !b.hasData && error == null;
                      final byId = {
                        for (final q in [...?a.data, ...?b.data])
                          if (q.status != RequestStatus.posted) q.id: q,
                      };
                      final all = byId.values.toList()
                        ..sort((x, y) => (x.dueDate ?? DateTime(9999))
                            .compareTo(y.dueDate ?? DateTime(9999)));
                      final counts = [
                        for (final s in _tabs)
                          all.where((q) => s == null || q.status == s).length,
                      ];
                      final shown = all
                          .where((q) =>
                              _tabs[_tab] == null || q.status == _tabs[_tab])
                          .toList();
                      return ListView(
                        padding: EdgeInsets.fromLTRB(
                            r.x(10), r.y(8), r.x(10), r.y(12)),
                        children: [
                          FilterChipsRow(
                            selected: _tab,
                            labels: _labels,
                            counts: counts,
                            idleColor: AppColors.bg,
                            selectedTextColor: AppColors.bg,
                            onChanged: (i) => setState(() => _tab = i),
                          ),
                          if (error != null)
                            emptyText(context, '読み込みに失敗しました：$error'),
                          if (waiting)
                            const Center(child: CircularProgressIndicator())
                          else if (shown.isEmpty)
                            emptyText(context, '該当する案件はありません'),
                          for (final q in shown)
                            Padding(
                              padding: EdgeInsets.only(bottom: r.y(10)),
                              child: StepProgressCard(
                                request: q,
                                role: q.requesterId == uid
                                    ? UserRole.requester
                                    : UserRole.editor,
                                uid: uid,
                                onTap: () {
                                  // 詳細は、その案件で自分が担う立場で開く。
                                  Services.repo.staffMode = q.requesterId == uid
                                      ? UserRole.requester
                                      : UserRole.editor;
                                  openRequest(context, q.id);
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
