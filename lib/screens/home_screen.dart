import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_tokens.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/home_logic.dart';
import '../domain/request_status.dart';
import '../domain/video_request.dart';
import '../widgets/app_drawer.dart';
import '../widgets/filter_chips_row.dart';
import '../widgets/home_widgets.dart';
import '../widgets/list_helpers.dart';
import '../widgets/role_builder.dart';
import '../widgets/unread_builder.dart';

/// 01 ホーム（進捗状況）。役割に応じて依頼者ホーム／編集者ホームを表示する。
/// 役割の付与・分岐方法はFigJamで未確定のため、roles/{uid} の値で切り替える暫定実装。
///
/// デザインシステム（docs/design-system/components.md の HomeScreen）の並び：
/// AppBar → TopTabs（進行中／完了）→ 期限が近い依頼（なければ EmptyCard）→
/// 絞り込み（Select と Chip）→ RequestCard の2列グリッド → TabBar（中央に主操作）。
/// 背景は surface-100、カードは surface-200。状態は色だけでなく語句で示す。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// 0=進行中、1=完了。
  int _tab = 0;
  HomeFilter _filter = HomeFilter.active;

  /// 担当の絞り込み。0=すべて、1=自分／決定済、2=未定。
  int _assignee = 0;

  /// 期限が近いとみなす日数（期限超過を含む）。
  static const _soonDays = 3;

  List<VideoRequest> _byAssignee(
      List<VideoRequest> list, UserRole role, String uid) {
    if (_assignee == 0) return list;
    return [
      for (final q in list)
        if (_assignee == 2
            ? q.editorId == null
            : (q.editorId != null &&
                (role != UserRole.editor || q.editorId == uid)))
          q
    ];
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: const AppDrawer(),
      body: RoleBuilder(
        builder: (context, uid, role) {
          final isEditor = role == UserRole.editor;
          return Column(
            children: [
              HomeAppBar(title: isEditor ? '編集者ホーム' : '依頼者ホーム'),
              Expanded(
                child: StreamBuilder<List<VideoRequest>>(
                  stream: isEditor
                      ? Services.repo.watchEditor(uid)
                      : Services.repo.watchRequester(uid),
                  builder: (context, snap) {
                    final all = snap.data ?? const <VideoRequest>[];
                    final waiting =
                        snap.connectionState == ConnectionState.waiting &&
                            !snap.hasData;
                    final now = DateTime.now();
                    final active = _byAssignee(
                        applyHomeFilter(all, role, HomeFilter.active),
                        role,
                        uid);
                    final soon = [
                      for (final q in active)
                        if ((daysUntilDue(q.dueDate, now) ?? 99) <= _soonDays) q
                    ]..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
                    final counts = [
                      for (final f in HomeFilter.values)
                        _byAssignee(applyHomeFilter(all, role, f), role, uid)
                            .length,
                    ];
                    final done = _tab == 1;
                    final shown = done
                        ? sortForHome(
                            _byAssignee([
                              for (final q in all)
                                if (q.status == RequestStatus.posted) q
                            ], role, uid),
                            role)
                        : sortForHome(
                            _byAssignee(
                                applyHomeFilter(all, role, _filter), role, uid),
                            role);
                    return Column(
                      children: [
                        TopTabs(
                          items: const ['進行中', '完了'],
                          active: _tab,
                          onSelect: (i) => setState(() => _tab = i),
                        ),
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.all(r.x(AppSpace.s4)),
                            children: [
                              if (!done) ...[
                                const SectionTitle('期限が近い依頼'),
                                SizedBox(height: r.y(AppSpace.s2)),
                                if (soon.isEmpty)
                                  const EmptyCard(
                                      text: '期限が近い依頼はありません')
                                else
                                  RequestGrid(children: [
                                    for (final q in soon.take(4))
                                      _card(context, q, role, uid, now),
                                  ]),
                                SizedBox(height: r.y(AppSpace.s6)),
                              ],
                              const SectionTitle('絞り込み'),
                              SizedBox(height: r.y(AppSpace.s2)),
                              SelectField(
                                label: '担当',
                                options: [
                                  'すべての担当',
                                  isEditor ? '担当 あなた' : '担当 決定済',
                                  '担当 未定',
                                ],
                                value: _assignee,
                                onChanged: (i) => setState(() => _assignee = i),
                              ),
                              if (!done) ...[
                                SizedBox(height: r.y(AppSpace.s3)),
                                FilterChipsRow(
                                  wrap: true,
                                  selected: _filter.index,
                                  labels: [
                                    for (final f in HomeFilter.values)
                                      f == HomeFilter.active ? 'すべて' : f.label,
                                  ],
                                  counts: counts,
                                  onChanged: (i) => setState(
                                      () => _filter = HomeFilter.values[i]),
                                ),
                              ],
                              SizedBox(height: r.y(AppSpace.s6)),
                              SectionTitle(done ? '完了した依頼' : '進行中の依頼'),
                              SizedBox(height: r.y(AppSpace.s2)),
                              if (snap.hasError)
                                emptyText(context,
                                    'エラー：読み込みに失敗しました（${snap.error}）。通信を確認して、もう一度開いてください'),
                              if (waiting)
                                const Center(
                                    child: CircularProgressIndicator())
                              else if (shown.isEmpty)
                                EmptyCard(
                                    text: done
                                        ? '完了した依頼はありません'
                                        : (_filter == HomeFilter.active
                                            ? '進行中の依頼はありません'
                                            : '該当する依頼はありません'))
                              else
                                RequestGrid(children: [
                                  for (final q in shown)
                                    _card(context, q, role, uid, now),
                                ]),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              UnreadBuilder(
                uid: uid,
                role: role,
                builder: (context, all, unread) => HomeTabBar(
                  activeLeft: 0,
                  left: [
                    const HomeTabItem(
                        label: 'ホーム',
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home),
                    HomeTabItem(
                      label: '依頼確認',
                      icon: Icons.assignment_outlined,
                      onTap: () => Navigator.of(context).pushNamed('/drawer'),
                    ),
                  ],
                  // 中央の主操作は画面に1つ。依頼者は新規依頼、編集者は進捗状況へ。
                  center: isEditor
                      ? HomeTabItem(
                          label: '進捗状況',
                          icon: Icons.insights,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/progress'),
                        )
                      : HomeTabItem(
                          label: '新規依頼',
                          icon: Icons.add,
                          onTap: () => Navigator.of(context).pushNamed('/chat'),
                        ),
                  right: [
                    HomeTabItem(
                      label: '通知',
                      icon: Icons.notifications_none,
                      activeIcon: Icons.notifications,
                      badge: unread.length,
                      onTap: () =>
                          Navigator.of(context).pushNamed('/notifications'),
                    ),
                    HomeTabItem(
                      label: 'メイン',
                      icon: Icons.apps,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, VideoRequest q, UserRole role, String uid,
          DateTime now) =>
      HomeRequestCard(
        request: q,
        role: role,
        uid: uid,
        now: now,
        onTap: () => openRequest(context, q.id),
      );
}
