import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/home_logic.dart';
import '../domain/request_status.dart';
import '../domain/video_request.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/filter_chips_row.dart';
import '../widgets/list_helpers.dart';
import '../widgets/role_builder.dart';
import '../widgets/step_progress_card.dart';
import '../widgets/unread_builder.dart';

/// 01 ホーム（進捗状況）。役割に応じて依頼者ホーム／編集者ホームを表示する。
/// 役割の付与・分岐方法はFigJamで未確定のため、roles/{uid} の値で切り替える暫定実装。
///
/// 上から「要対応サマリー」→（未読の通知を1件）→「絞り込み（件数つき）」→「案件」の順。
/// ホームは進行中の案件に絞り、完了した依頼は依頼確認・納品ライブラリで見る。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeFilter _filter = HomeFilter.active;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: RoleBuilder(
          builder: (context, uid, role) {
            final isEditor = role == UserRole.editor;
            return Column(
              children: [
                AppHeader(title: isEditor ? '編集者ホーム' : '依頼者ホーム'),
                Expanded(
                  child: StreamBuilder<List<VideoRequest>>(
                    stream: isEditor
                        ? Services.repo.watchEditor(uid)
                        : Services.repo.watchRequester(uid),
                    builder: (context, snap) {
                      final all = snap.data ?? const <VideoRequest>[];
                      final shown = sortForHome(
                          applyHomeFilter(all, role, _filter), role);
                      final counts = [
                        for (final f in HomeFilter.values)
                          applyHomeFilter(all, role, f).length,
                      ];
                      final mine = counts[HomeFilter.mine.index];
                      final waiting =
                          snap.connectionState == ConnectionState.waiting &&
                              !snap.hasData;
                      return Container(
                        color: Colors.white,
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                              r.x(10), r.y(10), r.x(10), r.y(12)),
                          children: [
                            _SummaryCard(
                              requests: all,
                              role: role,
                              count: mine,
                              onTap: mine == 0
                                  ? null
                                  : () =>
                                      setState(() => _filter = HomeFilter.mine),
                            ),
                            SizedBox(height: r.y(8)),
                            _LatestNotice(uid: uid, role: role),
                            FilterChipsRow(
                              selected: _filter.index,
                              labels: [
                                for (final f in HomeFilter.values) f.label,
                              ],
                              counts: counts,
                              onChanged: (i) => setState(
                                  () => _filter = HomeFilter.values[i]),
                            ),
                            if (snap.hasError)
                              emptyText(context, '読み込みに失敗しました：${snap.error}'),
                            if (waiting)
                              const Center(child: CircularProgressIndicator())
                            else if (shown.isEmpty)
                              emptyText(
                                  context,
                                  _filter == HomeFilter.active
                                      ? '進行中の依頼はありません'
                                      : '該当する依頼はありません'),
                            for (final req in shown)
                              Padding(
                                padding: EdgeInsets.only(bottom: r.y(10)),
                                child: StepProgressCard(
                                  request: req,
                                  role: role,
                                  uid: uid,
                                  onTap: () => openRequest(context, req.id),
                                ),
                              ),
                            _CompletedLink(
                              count: all
                                  .where(
                                      (q) => q.status == RequestStatus.posted)
                                  .length,
                              onTap: () =>
                                  Navigator.of(context).pushNamed('/drawer'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                _BottomActionBar(
                  uid: uid,
                  role: role,
                  onNew: () => Navigator.of(context).pushNamed('/chat'),
                  onCheck: () => Navigator.of(context).pushNamed('/drawer'),
                  onNotices: () =>
                      Navigator.of(context).pushNamed('/notifications'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 最上部の「要対応サマリー」。件数と内訳を示し、タップで要対応の案件に絞り込む。
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.requests,
    required this.role,
    required this.count,
    this.onTap,
  });

  final List<VideoRequest> requests;
  final UserRole role;
  final int count;
  final VoidCallback? onTap;

  /// 内訳（やることごとの件数）。
  List<String> get _breakdown {
    final counts = <String, int>{};
    for (final q in requests) {
      final label = _kind(q);
      if (label != null) counts[label] = (counts[label] ?? 0) + 1;
    }
    return [for (final e in counts.entries) '${e.key} ${e.value}件'];
  }

  String? _kind(VideoRequest q) {
    if (!needsMyAction(q, role)) return null;
    if (role == UserRole.requester) {
      return q.status == RequestStatus.needsInfo ? '要確認の回答' : '初稿の確認';
    }
    return switch (q.status) {
      RequestStatus.pending => '受付待ち',
      RequestStatus.editing => '編集中',
      RequestStatus.revision => '修正対応',
      _ => '投稿待ち',
    };
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final todo = count > 0;
    final color = todo ? AppColors.amber : AppColors.blue;
    return Semantics(
      button: todo,
      label: todo ? '要対応 $count件。タップで絞り込み' : '対応が必要な依頼はありません',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.x(14)),
          decoration: BoxDecoration(
            color: todo ? const Color(0xFFFFF7EA) : Colors.white,
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(r.x(16)),
          ),
          child: Row(
            children: [
              Container(
                width: r.x(52),
                height: r.x(52),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: todo
                    ? Text('$count',
                        style: AppText.noto(r.x(26),
                            color: Colors.white, height: 1.2))
                    : Icon(Icons.check, size: r.x(30), color: Colors.white),
              ),
              SizedBox(width: r.x(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(todo ? 'あなたの対応が必要です' : '対応が必要な依頼はありません',
                        style: AppText.noto(r.x(17), height: 1.4)),
                    if (todo)
                      // 単語の途中で折り返さないよう、項目ごとに折り返す。
                      Wrap(
                        spacing: r.x(10),
                        children: [
                          for (final t in _breakdown)
                            Text(t,
                                style: AppText.noto(r.x(14),
                                    weight: FontWeight.w500, height: 1.5)),
                        ],
                      ),
                  ],
                ),
              ),
              if (todo) Icon(Icons.chevron_right, size: r.x(28)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 未読の通知のうち最新の1件だけを出す。残りは件数で示し、通知画面で見る。
/// 未読がなければ何も出さない（古い通知が上部に残り続けない）。
class _LatestNotice extends StatelessWidget {
  const _LatestNotice({required this.uid, required this.role});

  final String uid;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return UnreadBuilder(
      uid: uid,
      role: role,
      builder: (context, all, unread) {
        if (unread.isEmpty) return const SizedBox.shrink();
        final latest = unread.first;
        final more = unread.length - 1;
        // ファーストビューを占有しないよう、1行の細い帯にする。残りは「+N」で示す。
        return Padding(
          padding: EdgeInsets.only(bottom: r.y(6)),
          child: Semantics(
            button: true,
            label:
                '新着の通知 ${unread.length}件。最新：${latest.message.split('\n').first}',
            child: GestureDetector(
              onTap: () => openRequest(context, latest.requestId),
              child: Container(
                constraints: BoxConstraints(minHeight: r.y(48)),
                padding:
                    EdgeInsets.symmetric(horizontal: r.x(12), vertical: r.y(6)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.amber),
                  borderRadius: BorderRadius.circular(r.x(14)),
                ),
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      Icon(Icons.notifications,
                          size: r.x(22), color: AppColors.amber),
                      SizedBox(width: r.x(8)),
                      Expanded(
                        child: Text(latest.message.split('\n').first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.noto(r.x(14), height: 1.5)),
                      ),
                      if (more > 0)
                        GestureDetector(
                          onTap: () =>
                              Navigator.of(context).pushNamed('/notifications'),
                          child: Container(
                            margin: EdgeInsets.only(left: r.x(8)),
                            padding: EdgeInsets.symmetric(
                                horizontal: r.x(10), vertical: r.y(3)),
                            decoration: BoxDecoration(
                              color: AppColors.amber,
                              borderRadius: BorderRadius.circular(r.x(12)),
                            ),
                            child: Text('+$more',
                                style: AppText.noto(r.x(13),
                                    color: Colors.white, height: 1.4)),
                          ),
                        ),
                      Icon(Icons.chevron_right, size: r.x(22)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 一覧の末尾。完了した依頼はここから依頼確認で見られる。
class _CompletedLink extends StatelessWidget {
  const _CompletedLink({required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: Text(
          count == 0 ? '完了した依頼は依頼確認で見られます' : '完了した依頼 $count件を依頼確認で見る',
          style: AppText.noto(r.x(14), color: AppColors.blue, height: 1.5),
        ),
      ),
    );
  }
}

/// 下部バー。依頼者の「新規依頼」は主操作として大きく分け、
/// 画面遷移の「依頼確認」「通知（未読バッジつき）」とは見た目を変える。
class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.uid,
    required this.role,
    this.onNew,
    this.onCheck,
    this.onNotices,
  });

  final String uid;
  final UserRole role;
  final VoidCallback? onNew;
  final VoidCallback? onCheck;
  final VoidCallback? onNotices;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.stepBorder)),
      ),
      padding: EdgeInsets.fromLTRB(r.x(10), r.y(8), r.x(10), r.y(6)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (role == UserRole.requester)
            SizedBox(
              width: double.infinity,
              height: r.y(54),
              child: FilledButton.icon(
                onPressed: onNew,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.x(16))),
                ),
                icon: Icon(Icons.add, size: r.x(28)),
                label: Text('新規依頼',
                    style: AppText.noto(r.x(18),
                        color: Colors.white, height: 1.4)),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _NavItem(
                    icon: Icons.assignment_outlined,
                    label: '依頼確認',
                    onTap: onCheck),
              ),
              Expanded(
                child: UnreadBuilder(
                  uid: uid,
                  role: role,
                  builder: (context, all, unread) => _NavItem(
                    icon: Icons.notifications_none,
                    label: '通知',
                    badge: unread.length,
                    onTap: onNotices,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.badge = 0,
    this.onTap,
  });

  final IconData icon;
  final String label;

  /// 未読の件数。0なら出さない。
  final int badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Semantics(
      button: true,
      label: badge > 0 ? '$label 未読$badge件' : label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.x(12)),
        child: SizedBox(
          height: r.y(56),
          child: ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Badge(
                  isLabelVisible: badge > 0,
                  backgroundColor: AppColors.danger,
                  label: Text(badge > 99 ? '99+' : '$badge'),
                  child: Icon(icon, size: r.x(28), color: AppColors.blue),
                ),
                SizedBox(width: r.x(8)),
                Text(label,
                    style: AppText.noto(r.x(16),
                        color: AppColors.blue, height: 1.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
