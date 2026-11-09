import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_tokens.dart';
import '../core/responsive.dart';
import '../domain/home_logic.dart';
import '../domain/request_status.dart';
import '../domain/video_request.dart';
import 'status_style.dart';

enum StepState { done, current, pending }

/// 「進捗確認カード」: 依頼名・納期・担当・誰の対応待ちか + 主線4段階の進捗。
/// 自分の対応が必要な依頼は、枠をaccent（塗り専用の色）で強調し、語句「あなたの対応待ち」を添える。
/// デザインシステム（docs/design-system）：カードは surface-200・radius-lg・余白 space-4、
/// 文字色に amber は使わない（注意の文字は warn）。
class StepProgressCard extends StatelessWidget {
  const StepProgressCard({
    super.key,
    required this.request,
    this.role,
    this.uid,
    this.onTap,
    this.now,
  });

  final VideoRequest request;

  /// 自分の役割。渡すと「あなたの対応待ち／相手の対応中」を表示する。
  final UserRole? role;
  final String? uid;
  final VoidCallback? onTap;

  /// 納期の残り日数の計算に使う現在日時（テスト用）。
  final DateTime? now;

  String get title => request.brief.title;

  bool get _mine => role != null && needsMyAction(request, role!);

  /// 主線4段階。現在位置より前は完了、投稿済のときは全て完了。
  List<(String, StepState)> get _steps {
    final cur = mainIndex(request.status);
    final posted = request.status == RequestStatus.posted;
    return [
      for (var i = 0; i < mainSteps.length; i++)
        (
          mainSteps[i].label,
          posted || i < cur
              ? StepState.done
              : (i == cur ? StepState.current : StepState.pending)
        ),
    ];
  }

  String get _assignee {
    if (request.editorId == null) return '担当 未定';
    if (role == UserRole.editor) {
      return request.editorId == uid ? '担当 あなた' : '担当 他の編集者';
    }
    return '担当 決定済';
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final steps = _steps;
    final mine = _mine;
    // 現在の段階の枠。要対応は accent、それ以外は brand。
    final accent = mine ? AppColors.amber : AppColors.blue;
    final action = role == null ? null : myActionLabel(request, role!);
    final waiting = role == null ? null : waitingLabel(request, role!);
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.x(AppSpace.s4)),
          decoration: BoxDecoration(
            color: AppColors.surface200,
            border: Border.all(
                color: mine ? AppColors.amber : AppColors.line,
                width: mine ? 2 : 1),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(title, style: AppText.h3(r))),
                  if (mine) ...[
                    SizedBox(width: r.x(AppSpace.s2)),
                    const _Tag(text: 'あなたの対応待ち', accent: true),
                  ] else if (waiting != null) ...[
                    SizedBox(width: r.x(AppSpace.s2)),
                    _Tag(text: waiting),
                  ] else if (request.status == RequestStatus.posted) ...[
                    SizedBox(width: r.x(AppSpace.s2)),
                    const _Tag(text: '完了'),
                  ],
                ],
              ),
              SizedBox(height: r.y(AppSpace.s1)),
              Wrap(
                spacing: r.x(AppSpace.s4),
                children: [
                  _DueText(
                    due: request.dueDate,
                    now: now ?? DateTime.now(),
                    done: request.status == RequestStatus.posted,
                  ),
                  Text(_assignee, style: AppText.body(r)),
                ],
              ),
              if (action != null)
                Text('次にやること：$action',
                    style: AppText.body(r,
                        color: AppColors.warn, weight: FontWeight.w700)),
              if (isBranch(request.status) || request.approved)
                Text(
                  isBranch(request.status)
                      ? '分岐：${request.status.label}'
                      : '承認済み・投稿待ち',
                  style: AppText.body(r, color: AppColors.warn),
                ),
              SizedBox(height: r.y(AppSpace.s3)),
              Row(
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    if (i > 0) SizedBox(width: r.x(AppSpace.s2)),
                    Expanded(
                      flex: steps[i].$2 == StepState.current ? 69 : 65,
                      child: _Step(
                          label: steps[i].$1,
                          state: steps[i].$2,
                          accent: accent),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 納期。期限超過は danger、3日以内は warn で強調し、必ず語句（超過・残り）を併記する。
class _DueText extends StatelessWidget {
  const _DueText({required this.due, required this.now, required this.done});

  final DateTime? due;
  final DateTime now;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final days = daysUntilDue(due, now);
    var color = AppColors.ink;
    var weight = FontWeight.w400;
    var suffix = '';
    if (days != null && !done) {
      if (days < 0) {
        color = AppColors.danger;
        weight = FontWeight.w700;
        suffix = '（${-days}日超過）';
      } else if (days == 0) {
        color = AppColors.warn;
        weight = FontWeight.w700;
        suffix = '（今日まで）';
      } else if (days <= 3) {
        color = AppColors.warn;
        weight = FontWeight.w700;
        suffix = '（残り$days日）';
      } else {
        suffix = '（残り$days日）';
      }
    }
    return Text('納期 ${dateText(due)}$suffix',
        style: AppText.body(r, color: color, weight: weight));
  }
}

/// タグ（radius-sm・label）。accent は塗りで、上の文字は on-accent（ink）。
class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.accent = false});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: r.x(AppSpace.s2), vertical: r.y(AppSpace.s1)),
      decoration: BoxDecoration(
        color: accent ? AppColors.amber : Colors.transparent,
        border: accent ? null : Border.all(color: AppColors.lineStrong),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(text,
          style: AppText.label(r,
              color: accent ? AppColors.onAmber : AppColors.inkMuted)),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.state, required this.accent});

  final String label;
  final StepState state;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final done = state == StepState.done;
    final current = state == StepState.current;

    // 状態は色だけでなく語句（✓／現在／未到達）でも示す。
    final top = done ? '✓' : (current ? '現在' : '未到達');
    final topColor = done
        ? AppColors.onBlue
        : (current ? AppColors.ink : AppColors.inkMuted);
    final bottomColor = done ? AppColors.onBlue : AppColors.ink;

    return Container(
      height: r.y(57),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? AppColors.blue : AppColors.surface200,
        border: Border.all(
          color: current ? accent : AppColors.lineStrong,
          width: current ? 3 : 1,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(top,
                style: AppText.body(r,
                    color: topColor,
                    weight: current ? FontWeight.w700 : FontWeight.w400)),
            SizedBox(height: r.y(AppSpace.s1)),
            Text(label,
                style: AppText.body(r,
                    color: bottomColor, weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
