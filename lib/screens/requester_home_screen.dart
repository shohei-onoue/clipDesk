import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/home_logic.dart';
import '../domain/request_status.dart';
import '../domain/video_request.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/attachment_thumb.dart';
import '../widgets/home_widgets.dart';
import '../widgets/list_helpers.dart';
import '../widgets/role_builder.dart';
import '../widgets/status_style.dart';

/// 依頼者ページ（Figma 290:123「home_screen」）。画面のタイトルは「ダッシュボード」。
/// メイン画面の「依頼者ページ」「編集者ダッシュボード」から開く。依頼を2列の「進捗カード」で並べる。
/// カード：上に動画のサムネイルと状態バッジ、下に題名・概要・進捗バー・編集担当。
class RequesterHomeScreen extends StatefulWidget {
  const RequesterHomeScreen({super.key});

  @override
  State<RequesterHomeScreen> createState() => _RequesterHomeScreenState();
}

class _RequesterHomeScreenState extends State<RequesterHomeScreen> {
  DashboardTab _tab = DashboardTab.all;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final uid = Services.uid;
    return StreamBuilder<UserRole?>(
      stream: uid == null ? null : Services.repo.watchRole(uid),
      builder: (context, roleSnap) {
        final editor = roleSnap.data == UserRole.editor;
        return _scaffold(context, r, editor);
      },
    );
  }

  Widget _scaffold(BuildContext context, Responsive r, bool editor) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      drawer: const AppDrawer(),
      drawerScrimColor: const Color(0x8A000000),
      bottomNavigationBar: const AppBottomBar(),
      body: SafeArea(
        child: Column(
          children: [
            // 依頼者・編集者どちらの立場でも、タイトルは「ダッシュボード」。
            const AppHeader(title: 'ダッシュボード'),
            Expanded(
              child: RoleBuilder(
                dark: true,
                builder: (context, uid, role) =>
                    StreamBuilder<List<VideoRequest>>(
                  // 登録スタッフは、権限に関わらず全案件のカードを見られる。
                  stream: Services.repo.watchAllRequests(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                          child: Text('エラー：読み込みに失敗しました。通信を確認して、もう一度開いてください',
                              textAlign: TextAlign.center,
                              style:
                                  AppText.dark(14, weight: FontWeight.w400)));
                    }
                    if (!snap.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.white));
                    }
                    final role = editor ? UserRole.editor : UserRole.requester;
                    final all = snap.data!;
                    final list =
                        sortForHome(applyDashboardTab(all, _tab), role);
                    return Column(
                      children: [
                        TopTabs(
                          items: [
                            for (final t in DashboardTab.values) t.label,
                          ],
                          active: _tab.index,
                          onSelect: (i) =>
                              setState(() => _tab = DashboardTab.values[i]),
                        ),
                        Expanded(
                          child: list.isEmpty
                              ? Padding(
                                  padding: EdgeInsets.all(r.x(14)),
                                  child: Align(
                                      alignment: Alignment.topCenter,
                                      child: EmptyCard(
                                          text: _tab == DashboardTab.all &&
                                                  !editor
                                              ? '進行中の依頼はありません。下の「＋」から新しい依頼を作れます'
                                              : _tab.emptyText)),
                                )
                              : Align(
                                  alignment: Alignment.topCenter,
                                  child: ConstrainedBox(
                                    constraints:
                                        BoxConstraints(maxWidth: r.x(393)),
                                    child: GridView.builder(
                                      padding: EdgeInsets.fromLTRB(
                                          r.x(14), r.x(16), r.x(14), r.x(16)),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: r.x(17),
                                        mainAxisSpacing: r.x(29),
                                        mainAxisExtent: r.x(310),
                                      ),
                                      itemCount: list.length,
                                      itemBuilder: (context, i) => ProgressCard(
                                        request: list[i],
                                        onTap: () =>
                                            openRequest(context, list[i].id),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 進捗カード（174×292、角丸10）。状態バッジは語句つき。
class ProgressCard extends StatelessWidget {
  const ProgressCard({super.key, required this.request, this.onTap, this.now});

  final VideoRequest request;
  final VoidCallback? onTap;

  /// 「新規依頼」の判定に使う今日。テスト用（省略時は現在時刻）。
  final DateTime? now;

  /// バッジ（文言・色・塗りか枠か）。タブごとに：
  /// 依頼＝新規依頼／受付待ち／問合せ、編集＝編集中／修正中、確認＝確認中／承認済、完了。
  (String, Color, bool) get _badge => switch (request.status) {
        RequestStatus.pending => (
            isNewRequest(request, now ?? DateTime.now()) ? '新規依頼' : '受付待ち',
            AppColors.amber,
            true
          ),
        RequestStatus.needsInfo => ('問合せ', AppColors.amber, false),
        RequestStatus.editing => ('編集中', AppColors.blue, true),
        RequestStatus.revision => ('修正中', AppColors.blue, true),
        RequestStatus.review => request.approved
            ? ('承認済', AppColors.blue, false)
            : ('確認中', AppColors.amber, false),
        RequestStatus.posted => ('完了', AppColors.blue, false),
      };

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final done = request.status == RequestStatus.posted;
    final (badgeText, badgeColor, badgeFilled) = _badge;
    final b = request.brief;
    final summary = b.purpose.isNotEmpty ? b.purpose : b.videoType;
    final value = request.status == RequestStatus.pending
        ? 0.0
        : progressValue(request.status);
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(r.x(10)),
          ),
          child: Column(
            children: [
              // サムネイル：最初に添付された動画または画像。
              SizedBox(
                height: r.x(160),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AttachmentThumb(
                        key: ValueKey(request.id),
                        attachment: thumbnailAttachment(request)),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: r.x(70),
                        height: r.x(30),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: badgeFilled ? badgeColor : AppColors.white,
                          border: badgeFilled
                              ? null
                              : Border.all(color: badgeColor),
                          borderRadius: BorderRadius.circular(r.x(10)),
                        ),
                        child: Text(badgeText,
                            style: AppText.noto(r.x(14),
                                color: badgeFilled
                                    ? AppColors.white
                                    : badgeColor)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: AppColors.white,
                  padding: EdgeInsets.all(r.x(5)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.title.isEmpty ? '（題名なし）' : b.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.noto(r.x(12), height: 1.3)),
                      SizedBox(height: r.x(4)),
                      SizedBox(
                        height: r.x(48),
                        child: Text(summary,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.noto(r.x(12),
                                weight: FontWeight.w400, height: 1.3)),
                      ),
                      const Spacer(),
                      Text('進捗状況', style: AppText.noto(r.x(12), height: 1.3)),
                      SizedBox(height: r.x(4)),
                      Container(
                        height: r.x(10),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: AppColors.ink.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(r.x(3)),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: value,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: done ? AppColors.blue : AppColors.amber,
                              borderRadius: BorderRadius.circular(r.x(3)),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: r.x(26),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text('編集担当',
                                style: AppText.noto(r.x(12), height: 1.3)),
                            SizedBox(width: r.x(20)),
                            Text(
                                request.editorName ??
                                    (request.editorId == null ? '未定' : '決定済'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.noto(r.x(14), height: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
