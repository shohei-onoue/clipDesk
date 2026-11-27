import 'package:flutter/material.dart' hide Text;
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/swipe_actions.dart';

import '../core/app_colors.dart';
import '../core/part_colors.dart';
import '../core/app_text.dart';
import '../core/app_tokens.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/request_status.dart';
import '../domain/staff_access.dart';
import '../domain/video_request.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/app_icon.dart';
import '../widgets/attachment_thumb.dart';
import '../widgets/library_upload_dialog.dart';
import '../widgets/list_helpers.dart';
import '../widgets/role_builder.dart';
import '../widgets/save_menu.dart';
import '../widgets/video_player_dialog.dart';
import '../widgets/ruby_text.dart';
import 'request_detail_screen.dart';

/// ライブラリ（Figma 302:7489）：投稿済みの編集完了動画の一覧。
/// 1本ずつカードにして縦に並べる。登録済みのスタッフは全員、全件を見られる。
/// 右下の「＋」から、完成済みの動画を直接追加できる。
/// カードを左にスライドすると削除ボタンが出る（依頼した本人は自分のカード、管理者は全カード）。
/// カードの右上のダウンロードアイコンから、保存先を選んで動画を保存できる。
class DeliveryLibraryScreen extends StatefulWidget {
  const DeliveryLibraryScreen({super.key});

  @override
  State<DeliveryLibraryScreen> createState() => _DeliveryLibraryScreenState();
}

/// 最初に読む件数と、スクロールで足す件数。
const _pageSize = 12;

class _DeliveryLibraryScreenState extends State<DeliveryLibraryScreen> {
  int _limit = _pageSize;
  Stream<List<VideoRequest>>? _stream;
  final _scroll = ScrollController();
  int _lastCount = 0;

  final _submissions = <(String, int), Future<Submission?>>{};

  Future<Submission?> _approvedSubmission(VideoRequest request) {
    final version = request.approvedVersion;
    if (version == null) return Future.value(null);
    final key = (request.id, version);
    return _submissions.putIfAbsent(key, () async {
      final submission = await Services.repo.getSubmission(request.id, version);
      if (submission == null) _submissions.remove(key);
      return submission;
    });
  }

  Stream<StaffAccess>? _access;
  String? _accessUid;

  /// ログイン中のスタッフの権限（管理者かどうか）。画面の作り直しで購読し直さないように保つ。
  Stream<StaffAccess> _watchAccess(String uid) {
    if (_accessUid != uid) {
      _accessUid = uid;
      _access = Services.repo.watchAccess(uid);
    }
    return _access!;
  }

  @override
  void initState() {
    super.initState();
    _stream = Services.repo.watchPostedRequests(limit: _limit);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// 終わり近くまでスクロールして、まだ続きがありそうなら、読む件数を増やす。
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final nearEnd = _scroll.position.extentAfter < 600;
    if (nearEnd && _lastCount >= _limit) {
      setState(() {
        _limit += _pageSize;
        _stream = Services.repo.watchPostedRequests(limit: _limit);
      });
    }
  }

  Future<void> _addVideo(String uid) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await showLibraryUploadDialog(context, uid: uid)) return;
    messenger.showSnackBar(const SnackBar(content: Text('ライブラリに追加しました')));
  }

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
              builder: (context, uid, role) => StreamBuilder<StaffAccess>(
                stream: _watchAccess(uid),
                builder: (context, access) => Stack(children: [
                  StreamBuilder<List<VideoRequest>>(
                    stream: _stream,
                    builder: (context, snap) {
                      // 投稿済みの動画だけをサーバーから取る（承認が新しい順）。
                      final approved = snap.data ?? const <VideoRequest>[];
                      _lastCount = approved.length;
                      return ListView.builder(
                        controller: _scroll,
                        // 下は、「＋」ボタンが最後のカードに重ならない分をあける。
                        padding:
                            EdgeInsets.fromLTRB(r.x(14), r.x(16), r.x(14), 88),
                        itemCount: approved.length + 1,
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            if (snap.hasError) {
                              return emptyTextDark(context,
                                  'エラー：読み込みに失敗しました（${snap.error}）。通信を確認して、もう一度開いてください');
                            }
                            if (approved.isEmpty &&
                                snap.connectionState !=
                                    ConnectionState.waiting) {
                              return emptyTextDark(context, '投稿済みの動画はまだありません');
                            }
                            return const SizedBox.shrink();
                          }
                          final q = approved[i - 1];
                          return Padding(
                            key: ValueKey((q.id, q.approvedVersion)),
                            padding: EdgeInsets.only(bottom: r.x(12)),
                            child: _LibraryCard(
                                request: q,
                                loadVideo: _approvedSubmission,
                                uid: uid,
                                role: role,
                                canDelete: q.requesterId == uid ||
                                    (access.data?.manager ?? false),
                                // 依頼確認の添付資料と同じく、編集者権限のスタッフだけ。
                                canDownload: access.data?.canEdit ?? false),
                          );
                        },
                      );
                    },
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton(
                      tooltip: '完成した動画を追加',
                      backgroundColor: PartColors.toggleFill,
                      foregroundColor: AppColors.on(PartColors.toggleFill),
                      onPressed: () => _addVideo(uid),
                      child: AppIcon(AppIcons.addCircle,
                          size: 32, color: AppColors.on(PartColors.toggleFill)),
                    ),
                  ),
                ]),
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
class _LibraryCard extends StatefulWidget {
  const _LibraryCard(
      {required this.request,
      required this.loadVideo,
      required this.uid,
      required this.role,
      required this.canDelete,
      required this.canDownload});
  final VideoRequest request;
  final Future<Submission?> Function(VideoRequest) loadVideo;
  final String uid;
  final UserRole role;

  /// 左にスライドして削除できるか。
  final bool canDelete;

  /// ダウンロードアイコンを出すか。
  final bool canDownload;

  @override
  State<_LibraryCard> createState() => _LibraryCardState();
}

class _LibraryCardState extends State<_LibraryCard> {
  /// 承認された版の提出動画。カードごとに購読せず、1回だけ読む（一覧に必要なのはこの1件だけ）。
  late final Future<Submission?> _video = widget.loadVideo(widget.request);

  VideoRequest get request => widget.request;
  String get uid => widget.uid;
  UserRole get role => widget.role;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return FutureBuilder<Submission?>(
      future: _video,
      builder: (context, snap) {
        final video = snap.data;
        final card = Semantics(
          button: true,
          label: '${request.brief.title}を再生する',
          child: GestureDetector(
            onTap: video == null
                // 直接追加した動画には、開ける依頼の画面がない。
                ? (request.libraryUpload
                    ? null
                    : () => openRequest(context, request.id))
                : () => showVideoDialog(context,
                    path: video.path,
                    title: request.brief.title,
                    // 直接追加した動画には指示書がないので、資料のボタンを出さない。
                    onDocs: request.libraryUpload
                        ? null
                        : () => showRequestDocsDialog(context,
                            request: request, uid: uid, role: role)),
            child: Container(
              padding: EdgeInsets.all(r.x(9)),
              decoration: BoxDecoration(
                color: AppColors.gray,
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
                              kind: 'video',
                              thumbPath: video.thumbPath)),
                ),
                SizedBox(width: r.x(16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 題名と、右上のダウンロードアイコン。
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(request.brief.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.dark(r.x(16),
                                      weight: FontWeight.w400,
                                      height: 20 / 16)),
                            ),
                            if (video != null && widget.canDownload)
                              _DownloadButton(video),
                          ]),
                      SizedBox(height: r.x(8)),
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
        // 依頼した本人と管理者は、左にスライドすると削除ボタンが出る。
        return widget.canDelete
            ? SwipeActions(
                actions: [
                  SwipeAction(
                    icon: Icons.delete_outline,
                    label: '削除',
                    color: AppColors.badgeRed,
                    onTap: () => _confirmDelete(context, request, uid),
                  ),
                ],
                child: card,
              )
            : card;
      },
    );
  }
}

/// 依頼確認の添付資料と同じダウンロードアイコン。
/// タップで保存先のメニューを開く（端末・Dropbox・Google ドライブ・OneDrive）。
class _DownloadButton extends StatelessWidget {
  const _DownloadButton(this.video);
  final Submission video;

  @override
  Widget build(BuildContext context) => Builder(
        // メニューをボタンの位置に出すため、ボタン自身の context を渡す。
        builder: (bctx) => IconButton(
          tooltip: 'ダウンロード（保存先を選ぶ）',
          color: AppColors.white,
          icon: const Icon(Icons.download),
          // カードが高くなりすぎないよう、タップ領域は40にする。
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          onPressed: () =>
              showSaveMenu(bctx, path: video.path, name: video.name),
        ),
      );
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
            foregroundColor: PartColors.onRed,
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
