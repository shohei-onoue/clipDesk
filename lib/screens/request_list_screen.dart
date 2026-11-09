import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/request_status.dart';
import '../domain/video_request.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/filter_chips_row.dart';
import '../widgets/list_helpers.dart';
import '../widgets/request_card.dart';
import '../widgets/role_builder.dart';
import '../widgets/status_style.dart';

/// 02 依頼一覧（編集者は「依頼確認」）。
class RequestListScreen extends StatefulWidget {
  const RequestListScreen({super.key, this.openDrawer = false});

  /// true の間は、表示と同時にドロワーを開く。
  final bool openDrawer;

  @override
  State<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends State<RequestListScreen> {
  final _key = GlobalKey<ScaffoldState>();
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    if (widget.openDrawer) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _key.currentState?.openDrawer());
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      key: _key,
      backgroundColor: AppColors.bg,
      drawer: const AppDrawer(),
      drawerScrimColor: const Color(0x8A000000),
      body: SafeArea(
        child: RoleBuilder(
          builder: (context, uid, role) {
            final isEditor = role == UserRole.editor;
            return Column(
              children: [
                AppHeader(
                  title: isEditor ? '依頼確認' : '依頼一覧',
                  titleSize: 32,
                  background: AppColors.bg,
                ),
                Expanded(
                  child: StreamBuilder<List<VideoRequest>>(
                    stream: isEditor
                        ? Services.repo.watchEditor(uid)
                        : Services.repo.watchRequester(uid),
                    builder: (context, snap) {
                      final all = snap.data ?? const <VideoRequest>[];
                      final shown = applyFilter(all, _filter);
                      return ListView(
                        padding: EdgeInsets.fromLTRB(
                            r.x(10), r.y(8), r.x(10), r.y(12)),
                        children: [
                          FilterChipsRow(
                            selected: _filter,
                            idleColor: AppColors.bg,
                            onChanged: (i) => setState(() => _filter = i),
                          ),
                          if (snap.hasError)
                            emptyText(context, '読み込みに失敗しました：${snap.error}'),
                          if (snap.connectionState == ConnectionState.waiting)
                            const Center(child: CircularProgressIndicator())
                          else if (shown.isEmpty)
                            emptyText(context, '該当する依頼はありません'),
                          for (final q in shown)
                            Padding(
                              padding: EdgeInsets.only(bottom: r.y(10)),
                              child: RequestCard(
                                progress: progressValue(q.status),
                                progressLabel: progressText(q),
                                title: q.brief.title,
                                meta:
                                    '納期 ${dateText(q.dueDate)}　担当 ${q.editorId == null ? '未定' : '決定済'}',
                                tag: q.statusLabel,
                                tagColor: tagColor(q.status),
                                tagTextColor: tagTextColor(q.status),
                                onTap: () => openRequest(context, q.id),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                if (!isEditor)
                  Padding(
                    padding: EdgeInsets.all(r.x(5)),
                    child: Material(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.circular(r.x(20)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(r.x(20)),
                        onTap: () => Navigator.of(context).pushNamed('/chat'),
                        child: SizedBox(
                          height: r.y(66),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.note_add,
                                  size: r.x(24), color: AppColors.bg),
                              SizedBox(width: r.x(14)),
                              Text('新規依頼',
                                  style: AppText.noto(r.x(16),
                                      color: AppColors.bg,
                                      height: 20.8 / 16,
                                      letterSpacing: 0.32)),
                            ],
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
    );
  }
}
