import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_tokens.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/request_status.dart';
import '../domain/video_request.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/attachment_thumb.dart';
import '../widgets/list_helpers.dart';
import '../widgets/role_builder.dart';
import '../widgets/video_player_dialog.dart';

/// ライブラリ（Figma 302:7489）：投稿済みの編集完了動画の一覧。
/// 1本ずつカードにして縦に並べる。登録済みのスタッフは全員、全件を見られる。
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
                stream: Services.repo.watchAllRequests(),
                builder: (context, snap) {
                  // 投稿済みの動画を、承認が新しい順に。
                  final approved = [
                    for (final q in snap.data ?? const <VideoRequest>[])
                      if (q.status == RequestStatus.posted) q
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
                        emptyTextDark(context, '投稿済みの動画はまだありません'),
                      for (final q in approved)
                        Padding(
                          padding: EdgeInsets.only(bottom: r.x(12)),
                          child: _LibraryCard(request: q, uid: uid),
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
  const _LibraryCard({required this.request, required this.uid});
  final VideoRequest request;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return StreamBuilder<List<Submission>>(
      stream: Services.repo.watchSubmissions(request.id),
      builder: (context, snap) {
        final subs = snap.data ?? const <Submission>[];
        final video =
            subs.where((s) => s.version == request.approvedVersion).firstOrNull;
        final card = Semantics(
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
                // 投稿された（承認された）動画の最初の1コマ。再生はせず、停止した状態で出す。
                // 動画がまだ読めない間は、薄い枠のままにする。
                Container(
                  width: r.x(87),
                  height: r.x(81),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(r.x(10)),
                  ),
                  child: video == null
                      ? Icon(Icons.play_arrow,
                          size: r.x(32), color: AppColors.white)
                      : AttachmentThumb(
                          key: ValueKey(video.path),
                          attachment: Attachment(
                              name: video.name,
                              path: video.path,
                              size: video.size,
                              kind: 'video')),
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
                      // 日付と編集者名の2行（高さ40）。右に、配信先のアイコンを同じ高さで並べる。
                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_dateTime(request.approvedAt),
                                  style: AppText.dark(r.x(14),
                                      weight: FontWeight.w400,
                                      height: 20 / 14)),
                              _EditorName(request.editorId, request.editorName),
                            ],
                          ),
                        ),
                        _PlatformIcons(request.brief.platform, height: r.x(40)),
                      ]),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        );
        // 依頼者本人のカードだけ、左にスワイプすると削除ボタンが出る。
        return request.requesterId == uid
            ? _SwipeToDelete(
                label: '${request.brief.title}を削除',
                onDelete: () => _confirmDelete(context, request, uid),
                child: card,
              )
            : card;
      },
    );
  }
}

/// 削除の確認。「削除」を選んだときだけ、依頼ごと（動画・記録も）消す。元には戻せない。
Future<void> _confirmDelete(
    BuildContext context, VideoRequest request, String uid) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.white.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text('削除しますか？', style: AppText.dark(18)),
      content: Text('「${request.brief.title}」を、動画も含めて完全に削除します。元には戻せません。',
          style: AppText.dark(14, weight: FontWeight.w400, height: 1.5)),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.white,
            side: BorderSide(color: AppColors.white.withValues(alpha: 0.55)),
            minimumSize: const Size(96, 44),
          ),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.badgeRed,
            foregroundColor: AppColors.white,
            minimumSize: const Size(96, 44),
          ),
          child: const Text('削除'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await Services.repo.deletePostedRequest(requestId: request.id, uid: uid);
    messenger.showSnackBar(const SnackBar(content: Text('削除しました')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('失敗しました：$e')));
  }
}

/// 左にスワイプすると、右端から削除ボタンが現れる（途中で離すと、半分を超えていれば開き、
/// 超えていなければ閉じる。アニメーションで動く）。開いているときにカードをタップすると閉じる。
class _SwipeToDelete extends StatefulWidget {
  const _SwipeToDelete(
      {required this.child, required this.onDelete, required this.label});
  final Widget child;
  final VoidCallback onDelete;
  final String label;

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220));
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _settle({double? velocity}) {
    final open = (velocity != null && velocity.abs() > 300)
        ? velocity < 0
        : _c.value > 0.5;
    _c.animateTo(open ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final width = r.x(88);
    return GestureDetector(
      onHorizontalDragUpdate: (d) =>
          _c.value = (_c.value - d.delta.dx / width).clamp(0.0, 1.0),
      onHorizontalDragEnd: (d) => _settle(velocity: d.primaryVelocity),
      child: Stack(children: [
        // 後ろにある削除ボタン。カードが左へ動くにつれて、右端から現れる。
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            // Behind motion：ボタンは濃いまま、後ろに固定。カードが左へ滑って空いた分だけ見える
            // （カードの背景は透けるので、閉じているときは見えないように、空いた幅で切り取る）。
            child: AnimatedBuilder(
              animation: _t,
              builder: (_, child) => ClipRect(
                child: Align(
                    alignment: Alignment.centerRight,
                    widthFactor: _t.value,
                    child: child),
              ),
              child: Semantics(
                button: true,
                label: widget.label,
                child: GestureDetector(
                  onTap: () {
                    _c.animateTo(0);
                    widget.onDelete();
                  },
                  child: Container(
                    width: width,
                    margin: EdgeInsets.only(left: r.x(4)),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.badgeRed,
                      borderRadius: BorderRadius.circular(r.x(15)),
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline,
                              color: AppColors.white, size: r.x(26)),
                          Text('削除',
                              style: AppText.dark(r.x(12),
                                  color: AppColors.white)),
                        ]),
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _t,
          builder: (_, child) => Transform.translate(
              offset: Offset(-(width + r.x(4)) * _t.value, 0), child: child),
          // 開いているときは、カードのタップは閉じるだけ（再生しない）。
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, child) => GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _c.value > 0.05 ? () => _c.animateTo(0) : null,
              child: IgnorePointer(ignoring: _c.value > 0.05, child: child),
            ),
            child: widget.child,
          ),
        ),
      ]),
    );
  }
}

/// 配信先（「、」区切り）に当てはまるアイコンを、高さ [height] で右に並べる。
/// 当てはまるものがない（「その他」など）ときは何も出さない。幅が足りないときは縮める。
class _PlatformIcons extends StatelessWidget {
  const _PlatformIcons(this.platform, {required this.height});
  final String platform;
  final double height;

  static const _assets = {
    'instagram': 'assets/icons/instagram.svg',
    'tiktok': 'assets/icons/tiktok.svg',
    'youtube': 'assets/icons/youtube.svg',
    'threads': 'assets/icons/threads.svg',
    'x': 'assets/icons/x_twitter.svg',
    'twitter': 'assets/icons/x_twitter.svg',
    'facebook': 'assets/icons/facebook.svg',
  };

  @override
  Widget build(BuildContext context) {
    final names = platform
        .split(RegExp(r'[、,，]'))
        .map((e) => e.trim().toLowerCase())
        .where(_assets.containsKey)
        .toSet()
        .toList();
    if (names.isEmpty) return const SizedBox.shrink();
    // 日付・編集者名の列が残りの幅をとり、アイコンは右端に詰める（多いときは縮める）。
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: height * 3.6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          // 3つ以上のときは、2つだけ出して、右に「…」を添える（ほかにもあることを示す）。
          for (final n in names.take(names.length >= 3 ? 2 : names.length))
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: SvgPicture.asset(_assets[n]!,
                  width: height, height: height, semanticsLabel: n),
            ),
          if (names.length >= 3)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Semantics(
                label: 'ほかにも${names.length - 2}件',
                child: Text('…',
                    style: AppText.dark(height * 0.6,
                        weight: FontWeight.w400, height: 1)),
              ),
            ),
        ]),
      ),
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
