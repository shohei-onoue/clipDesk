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
import '../widgets/status_style.dart';

/// 依頼一覧（Figma 284:1673「list_ccreen」。編集者は同じ画面を「依頼確認」として使う）。
/// 上から、グラデーションの下線つきヘッダー、依頼の2列グリッド、下部の共通バー（AppBottomBar）。
/// 背景はダーク（AppColors.ink）。カードは上に動画の静止画、下に題名・依頼名・進捗バー。
///
/// 動画の静止画はデータにまだ無いので、代わりの面とアイコンを置く。
/// 状態の語句はデザインに無いため、読み上げ用の Semantics にだけ含める。
class RequestListScreen extends StatefulWidget {
  const RequestListScreen({super.key, this.openDrawer = false});

  /// true の間は、表示と同時にドロワーを開く。
  final bool openDrawer;

  @override
  State<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends State<RequestListScreen> {
  final _key = GlobalKey<ScaffoldState>();

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
      backgroundColor: AppColors.ink,
      drawer: const AppDrawer(),
      drawerScrimColor: const Color(0x8A000000),
      body: SafeArea(
        child: RoleBuilder(
          dark: true,
          builder: (context, uid, role) {
            final isEditor = role == UserRole.editor;
            return Column(
              children: [
                const AppHeader(title: 'List'),
                Expanded(
                  child: StreamBuilder<List<VideoRequest>>(
                    stream: isEditor
                        ? Services.repo.watchEditor(uid)
                        : Services.repo.watchRequester(uid),
                    builder: (context, snap) {
                      final all = snap.data ?? const <VideoRequest>[];
                      if (snap.hasError) {
                        return _Message('エラー：読み込みに失敗しました（${snap.error}）。'
                            '通信を確認して、もう一度開いてください');
                      }
                      if (snap.connectionState == ConnectionState.waiting &&
                          !snap.hasData) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.white));
                      }
                      if (all.isEmpty) return const _Message('依頼はまだありません');
                      return GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                            r.x(14), r.x(27), r.x(14), r.x(27)),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: r.x(20),
                          // 行の間隔：行の高さ333.5 から カードの高さ270 を引いた値。
                          mainAxisSpacing: r.x(63.5),
                          mainAxisExtent: r.x(270),
                        ),
                        itemCount: all.length,
                        itemBuilder: (context, i) => _RequestTile(
                          request: all[i],
                          onTap: () => openRequest(context, all[i].id),
                        ),
                      );
                    },
                  ),
                ),
                const AppBottomBar(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 依頼1件のカード（幅は列の幅、高さ270）。上160が動画の静止画、下110が詳細。
class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request, this.onTap});

  final VideoRequest request;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final label = '${request.brief.title}、${request.statusLabel}、'
        '進捗 ${progressText(request)}';
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: ExcludeSemantics(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(color: AppColors.ink),
            child: Column(
              children: [
                // 動画の静止画の場所（データが無いので代わりの面）。
                Container(
                  height: r.x(160),
                  width: double.infinity,
                  color: AppColors.ink.withValues(alpha: 0.7),
                  alignment: Alignment.center,
                  child: Icon(Icons.movie_outlined,
                      size: r.x(48), color: AppColors.white),
                ),
                Container(
                  height: r.x(110),
                  width: double.infinity,
                  padding: EdgeInsets.all(r.x(5)),
                  color: AppColors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('-タイトル-', style: _text(r, bold: true)),
                      SizedBox(height: r.x(4)),
                      SizedBox(
                        height: r.x(45),
                        child: Text(request.brief.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: _text(r)),
                      ),
                      SizedBox(height: r.x(4)),
                      Text('-進捗状況-', style: _text(r, bold: true)),
                      SizedBox(height: r.x(4)),
                      _ProgressTrack(value: progressValue(request.status)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _text(Responsive r, {bool bold = false}) => AppText.noto(r.x(12),
      weight: bold ? FontWeight.w700 : FontWeight.w400, color: AppColors.ink);
}

/// 進捗バー：高さ10、角丸3。トラックは暗い色、進んだ分は accent の塗り。
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return ClipRRect(
      borderRadius: BorderRadius.circular(r.x(3)),
      child: Stack(
        children: [
          Container(
              height: r.x(10), color: AppColors.ink.withValues(alpha: 0.7)),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(height: r.x(10), color: AppColors.amber),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.x(24)),
        child: Text(text,
            textAlign: TextAlign.center,
            style: AppText.noto(r.x(14),
                weight: FontWeight.w400, color: AppColors.white)),
      ),
    );
  }
}
