import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../domain/request_status.dart';
import '../domain/video_request.dart';

/// フィルタ番号（0=すべて、1〜=進捗の並び順）で依頼を絞り込む。
List<VideoRequest> applyFilter(List<VideoRequest> all, int filter) {
  if (filter <= 0) return all;
  final s = RequestStatus.values[filter - 1];
  return [
    for (final r in all)
      if (r.status == s) r
  ];
}

/// ホームのお知らせ文。依頼者は確認待ちの動画、編集者は対応が必要な依頼を数える。
String? noticeText(List<VideoRequest> all, UserRole role) {
  if (role == UserRole.requester) {
    final n = all
        .where((r) => r.status == RequestStatus.review && !r.approved)
        .length;
    return n == 0 ? null : '編集済みの動画が届いています（チェック依頼 $n 件）';
  }
  final pending = all.where((r) => r.status == RequestStatus.pending).length;
  final rev = all.where((r) => r.status == RequestStatus.revision).length;
  final post =
      all.where((r) => r.status == RequestStatus.review && r.approved).length;
  final parts = [
    if (pending > 0) '受付待ち $pending 件',
    if (rev > 0) '修正依頼 $rev 件',
    if (post > 0) '投稿待ち $post 件',
  ];
  return parts.isEmpty ? null : '対応が必要な依頼があります（${parts.join('・')}）';
}

void openRequest(BuildContext context, String id) =>
    Navigator.of(context).pushNamed('/request', arguments: id);

Widget emptyText(BuildContext context, String text,
        {Color color = AppColors.ink}) =>
    Padding(
      padding: EdgeInsets.symmetric(vertical: context.r.y(24)),
      child: Center(
          child: Text(text,
              textAlign: TextAlign.center,
              style: AppText.noto(context.r.x(15), color: color))),
    );

/// ダーク背景の画面用の空表示。
Widget emptyTextDark(BuildContext context, String text) =>
    emptyText(context, text, color: AppColors.white);
