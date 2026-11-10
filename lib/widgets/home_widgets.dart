import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_tokens.dart';
import '../core/responsive.dart';
import '../domain/home_logic.dart';
import '../domain/request_status.dart';
import '../domain/video_request.dart';
import 'status_style.dart';

// デザインシステム（docs/design-system/components.md）のホーム用部品：
// TopTabs／EmptyCard／StatusTag／ProgressBar／RequestCard（グリッド用）。ダークテイスト。
// AppBar は AppHeader、下のバーは AppBottomBar を使う。

/// TopTabs：2〜3項目。選択中は brand の文字と4pxの下線、他は ink-muted。
class TopTabs extends StatelessWidget {
  const TopTabs({
    super.key,
    required this.items,
    required this.active,
    required this.onSelect,
  });

  final List<String> items;
  final int active;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.ink,
        border: Border(
            bottom: BorderSide(color: AppColors.white.withValues(alpha: 0.16))),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == active,
                label: items[i],
                child: InkWell(
                  onTap: () => onSelect(i),
                  child: ExcludeSemantics(
                    child: Container(
                      height: r.y(48),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                              color: i == active
                                  ? AppColors.blue
                                  : Colors.transparent,
                              width: 4),
                        ),
                      ),
                      child: Text(items[i],
                          style: AppText.body(r,
                              color: i == active
                                  ? AppColors.white
                                  : AppColors.white.withValues(alpha: 0.7),
                              weight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// セクション見出し（h3）。
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppText.h3(context.r, color: AppColors.white));
}

/// EmptyCard：該当がないときの枠。理由と次の操作を短く書く。
class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.x(AppSpace.s4)),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Text(text,
          style:
              AppText.body(r, color: AppColors.white.withValues(alpha: 0.7))),
    );
  }
}

/// Select：端末標準のプルダウン。高さ48、枠は line-strong、先頭は「すべての〜」。
class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label(r, color: AppColors.white)),
        SizedBox(height: r.y(AppSpace.s1)),
        Container(
          height: r.y(48),
          padding: EdgeInsets.symmetric(horizontal: r.x(AppSpace.s3)),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.08),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.55)),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: value,
              dropdownColor: AppColors.white.withValues(alpha: 0.08),
              style: AppText.body(r, color: AppColors.white),
              icon: const Icon(Icons.expand_more, color: AppColors.white),
              items: [
                for (var i = 0; i < options.length; i++)
                  DropdownMenuItem(value: i, child: Text(options[i])),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// StatusTag：状態を語句で示す。塗りの上の文字は on-brand／on-accent。
class StatusTag extends StatelessWidget {
  const StatusTag({super.key, required this.text, this.fill, this.onFill});

  final String text;
  final Color? fill;
  final Color? onFill;

  factory StatusTag.of(RequestStatus s) => StatusTag(
        text: s.label,
        fill: tagColor(s),
        onFill:
            tagColor(s) == AppColors.amber ? AppColors.ink : AppColors.white,
      );

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final filled = fill != null;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: r.x(AppSpace.s2), vertical: r.y(AppSpace.s1)),
      decoration: BoxDecoration(
        color: fill,
        border: filled
            ? null
            : Border.all(color: AppColors.white.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(text,
          style: AppText.label(r,
              color: filled
                  ? (onFill ?? AppColors.ink)
                  : AppColors.white.withValues(alpha: 0.7))),
    );
  }
}

/// ProgressBar：進捗（0〜1）。数値は呼び出し側が横に添える。
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Stack(
        children: [
          Container(
              height: r.y(AppSpace.s2),
              color: AppColors.white.withValues(alpha: 0.16)),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(height: r.y(AppSpace.s2), color: AppColors.amber),
          ),
        ],
      ),
    );
  }
}

/// RequestCard（ホームの2列グリッド用）：依頼名（2行まで）、状態タグ、進捗バーと数値、納期、担当。
/// 自分の対応待ちは accent の枠と、語句「あなたの対応待ち」で示す。
class HomeRequestCard extends StatelessWidget {
  const HomeRequestCard({
    super.key,
    required this.request,
    required this.role,
    required this.uid,
    this.onTap,
    this.now,
  });

  final VideoRequest request;
  final UserRole role;
  final String uid;
  final VoidCallback? onTap;
  final DateTime? now;

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
    final mine = needsMyAction(request, role);
    final done = request.status == RequestStatus.posted;
    final days =
        done ? null : daysUntilDue(request.dueDate, now ?? DateTime.now());
    var dueColor = AppColors.white;
    var dueWeight = FontWeight.w400;
    var dueSuffix = '';
    if (days != null) {
      if (days < 0) {
        dueColor = AppColors.amber;
        dueWeight = FontWeight.w700;
        dueSuffix = '（${-days}日超過）';
      } else if (days <= 3) {
        dueColor = AppColors.amber;
        dueWeight = FontWeight.w700;
        dueSuffix = days == 0 ? '（今日まで）' : '（残り$days日）';
      }
    }
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.x(AppSpace.s3)),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.08),
            border: Border.all(
                color: mine
                    ? AppColors.amber
                    : AppColors.white.withValues(alpha: 0.16),
                width: mine ? 2 : 1),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(request.brief.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(r,
                      color: AppColors.white, weight: FontWeight.w700)),
              SizedBox(height: r.y(AppSpace.s2)),
              Wrap(
                spacing: r.x(AppSpace.s1),
                runSpacing: r.y(AppSpace.s1),
                children: [
                  StatusTag.of(request.status),
                  if (mine)
                    const StatusTag(
                        text: 'あなたの対応待ち',
                        fill: AppColors.amber,
                        onFill: AppColors.ink),
                ],
              ),
              SizedBox(height: r.y(AppSpace.s2)),
              Row(
                children: [
                  Expanded(
                      child: ProgressBar(value: progressValue(request.status))),
                  SizedBox(width: r.x(AppSpace.s2)),
                  Text(progressText(request),
                      style: AppText.label(r, color: AppColors.white)),
                ],
              ),
              SizedBox(height: r.y(AppSpace.s2)),
              Text('納期 ${dateText(request.dueDate)}$dueSuffix',
                  style: AppText.bodySm(r, color: dueColor)
                      .copyWith(fontWeight: dueWeight)),
              Text(_assignee,
                  style: AppText.bodySm(r,
                      color: AppColors.white.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }
}

/// RequestCard の2列グリッド（gap space-3）。同じ行のカードは高さをそろえる。
class RequestGrid extends StatelessWidget {
  const RequestGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final gap = r.x(AppSpace.s3);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      if (i > 0) rows.add(SizedBox(height: r.y(AppSpace.s3)));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: children[i]),
            SizedBox(width: gap),
            Expanded(
                child: i + 1 < children.length
                    ? children[i + 1]
                    : const SizedBox.shrink()),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }
}
