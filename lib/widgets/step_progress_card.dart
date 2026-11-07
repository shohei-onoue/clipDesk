import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../domain/home_logic.dart';
import '../domain/request_status.dart';
import '../domain/video_request.dart';
import 'status_style.dart';

enum StepState { done, current, pending }

/// 「進捗確認カード」: 依頼名・納期・担当・誰の対応待ちか + 主線4段階の進捗。
/// 自分の対応が必要な依頼は、枠と現在の段階を警告色（amber）で強調する。
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
    final accent = mine ? AppColors.amber : AppColors.blue;
    final action = role == null ? null : myActionLabel(request, role!);
    final waiting = role == null ? null : waitingLabel(request, role!);
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: r.x(8), vertical: r.y(12)),
          decoration: BoxDecoration(
            color: mine ? const Color(0xFFFFF7EA) : Colors.white,
            border: Border.all(color: accent, width: mine ? 3 : 2),
            borderRadius: BorderRadius.circular(r.x(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.x(4)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(title,
                          style: AppText.noto(r.x(20), height: 1.5)),
                    ),
                    if (mine) ...[
                      SizedBox(width: r.x(8)),
                      _Badge(
                        text: 'あなたの対応待ち',
                        color: AppColors.amber,
                        filled: true,
                      ),
                    ] else if (waiting != null) ...[
                      SizedBox(width: r.x(8)),
                      _Badge(
                          text: waiting,
                          color: AppColors.stepGrey,
                          filled: false),
                    ] else if (request.status == RequestStatus.posted) ...[
                      SizedBox(width: r.x(8)),
                      _Badge(
                          text: '完了', color: AppColors.stepGrey, filled: false),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(r.x(4), r.y(2), r.x(4), 0),
                child: Wrap(
                  spacing: r.x(14),
                  runSpacing: r.y(2),
                  children: [
                    _DueText(
                      due: request.dueDate,
                      now: now ?? DateTime.now(),
                      done: request.status == RequestStatus.posted,
                    ),
                    Text(_assignee,
                        style: AppText.noto(r.x(14),
                            weight: FontWeight.w500, height: 1.5)),
                  ],
                ),
              ),
              if (action != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(r.x(4), r.y(4), r.x(4), 0),
                  child: Text('次にやること：$action',
                      style: AppText.noto(r.x(14),
                          color: AppColors.amber, height: 1.5)),
                ),
              if (isBranch(request.status) || request.approved)
                Padding(
                  padding: EdgeInsets.fromLTRB(r.x(4), r.y(2), r.x(4), 0),
                  child: Text(
                    isBranch(request.status)
                        ? '分岐：${request.status.label}'
                        : '承認済み・投稿待ち',
                    style: AppText.noto(r.x(14),
                        color: AppColors.amber, height: 1.5),
                  ),
                ),
              SizedBox(height: r.y(10)),
              Row(
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    if (i > 0) SizedBox(width: r.x(8)),
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

/// 納期。期限超過は赤、3日以内はamberで強調する。
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
    var weight = FontWeight.w500;
    var suffix = '';
    if (days != null && !done) {
      if (days < 0) {
        color = AppColors.danger;
        weight = FontWeight.w700;
        suffix = '（${-days}日超過）';
      } else if (days == 0) {
        color = AppColors.amber;
        weight = FontWeight.w700;
        suffix = '（今日まで）';
      } else if (days <= 3) {
        color = AppColors.amber;
        weight = FontWeight.w700;
        suffix = '（残り$days日）';
      } else {
        suffix = '（残り$days日）';
      }
    }
    return Text('納期 ${dateText(due)}$suffix',
        style:
            AppText.noto(r.x(14), color: color, weight: weight, height: 1.5));
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, required this.filled});

  final String text;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.x(10), vertical: r.y(3)),
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(r.x(12)),
      ),
      child: Text(text,
          style: AppText.noto(r.x(13),
              color: filled ? Colors.white : color, height: 1.4)),
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

    final top = done ? '✓' : (current ? '現在' : '未到達');
    final topColor =
        done ? Colors.white : (current ? accent : AppColors.stepGrey);
    final bottomColor = done ? Colors.white : AppColors.ink;

    return Container(
      height: r.y(57),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? AppColors.blue : Colors.white,
        border: Border.all(
          color: current ? accent : AppColors.stepBorder,
          width: current ? 3 : 1,
        ),
        borderRadius: BorderRadius.circular(r.x(6)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(top,
                style: AppText.noto(r.x(14), color: topColor, height: 1.5)),
            SizedBox(height: r.y(4)),
            Text(label,
                style: AppText.noto(r.x(14), color: bottomColor, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
