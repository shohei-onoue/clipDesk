import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../domain/request_status.dart';
import '../domain/video_request.dart';

/// 進捗の主線（受付待ち→編集中→初稿確認→投稿済）。要確認・修正は分岐。
const mainSteps = [
  RequestStatus.pending,
  RequestStatus.editing,
  RequestStatus.review,
  RequestStatus.posted,
];

/// 主線上の位置。要確認は受付待ち、修正は編集中の位置に分岐として載せる。
int mainIndex(RequestStatus s) => switch (s) {
      RequestStatus.pending || RequestStatus.needsInfo => 0,
      RequestStatus.editing || RequestStatus.revision => 1,
      RequestStatus.review => 2,
      RequestStatus.posted => 3,
    };

double progressValue(RequestStatus s) => (mainIndex(s) + 1) / mainSteps.length;

String progressText(VideoRequest r) => r.status == RequestStatus.posted
    ? '完了'
    : '${(progressValue(r.status) * 100).round()}%';

bool isBranch(RequestStatus s) =>
    s == RequestStatus.needsInfo || s == RequestStatus.revision;

Color tagColor(RequestStatus s) => switch (s) {
      RequestStatus.needsInfo || RequestStatus.revision => AppColors.amber,
      RequestStatus.review => AppColors.amber,
      _ => AppColors.blue,
    };

Color tagTextColor(RequestStatus s) =>
    tagColor(s) == AppColors.amber ? AppColors.ink : AppColors.bg;

String dateText(DateTime? d) => d == null
    ? '未設定'
    : '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
