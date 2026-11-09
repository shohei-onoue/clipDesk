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
// AppBar／TopTabs／EmptyCard／StatusTag／ProgressBar／RequestCard（グリッド用）／TabBar。

/// AppBar：brand 塗り、タイトルは中央、アイコンボタンには label を付ける。
/// 状態バーの下まで brand を敷くため、上側の SafeArea をここで持つ。
class HomeAppBar extends StatelessWidget {
  const HomeAppBar({super.key, required this.title, this.onMenu});

  final String title;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final side = r.x(AppSpace.s6 + AppSpace.s6); // 48：左右を同じ幅にして中央を保つ
    return ColoredBox(
      color: AppColors.blue,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: r.y(56),
          child: Row(
            children: [
              SizedBox(width: r.x(AppSpace.s1)),
              SizedBox(
                width: side,
                height: side,
                child: IconButton(
                  tooltip: 'メニューを開く',
                  onPressed:
                      onMenu ?? () => Scaffold.maybeOf(context)?.openDrawer(),
                  icon: Icon(Icons.menu,
                      size: r.x(AppSpace.s6), color: AppColors.onBlue),
                ),
              ),
              Expanded(
                child: Text(title,
                    textAlign: TextAlign.center,
                    style: AppText.h2(r, color: AppColors.onBlue)),
              ),
              SizedBox(width: side + r.x(AppSpace.s1)),
            ],
          ),
        ),
      ),
    );
  }
}

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
      decoration: const BoxDecoration(
        color: AppColors.surface200,
        border: Border(bottom: BorderSide(color: AppColors.line)),
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
                                  ? AppColors.blue
                                  : AppColors.inkMuted,
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
      Text(text, style: AppText.h3(context.r));
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
        color: AppColors.surface200,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Text(text, style: AppText.body(r, color: AppColors.inkMuted)),
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
        Text(label, style: AppText.label(r)),
        SizedBox(height: r.y(AppSpace.s1)),
        Container(
          height: r.y(48),
          padding: EdgeInsets.symmetric(horizontal: r.x(AppSpace.s3)),
          decoration: BoxDecoration(
            color: AppColors.surface200,
            border: Border.all(color: AppColors.lineStrong),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: value,
              dropdownColor: AppColors.surface200,
              style: AppText.body(r),
              icon: const Icon(Icons.expand_more, color: AppColors.ink),
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
            tagColor(s) == AppColors.amber ? AppColors.onAmber : AppColors.onBlue,
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
        border: filled ? null : Border.all(color: AppColors.lineStrong),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(text,
          style: AppText.label(r,
              color: filled ? (onFill ?? AppColors.ink) : AppColors.inkMuted)),
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
          Container(height: r.y(AppSpace.s2), color: AppColors.surface300),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(height: r.y(AppSpace.s2), color: AppColors.blue),
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
    final days = done ? null : daysUntilDue(request.dueDate, now ?? DateTime.now());
    var dueColor = AppColors.ink;
    var dueWeight = FontWeight.w400;
    var dueSuffix = '';
    if (days != null) {
      if (days < 0) {
        dueColor = AppColors.danger;
        dueWeight = FontWeight.w700;
        dueSuffix = '（${-days}日超過）';
      } else if (days <= 3) {
        dueColor = AppColors.warn;
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
            color: AppColors.surface200,
            border: Border.all(
                color: mine ? AppColors.amber : AppColors.line,
                width: mine ? 2 : 1),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(request.brief.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(r, weight: FontWeight.w700)),
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
                        onFill: AppColors.onAmber),
                ],
              ),
              SizedBox(height: r.y(AppSpace.s2)),
              Row(
                children: [
                  Expanded(child: ProgressBar(value: progressValue(request.status))),
                  SizedBox(width: r.x(AppSpace.s2)),
                  Text(progressText(request), style: AppText.label(r)),
                ],
              ),
              SizedBox(height: r.y(AppSpace.s2)),
              Text('納期 ${dateText(request.dueDate)}$dueSuffix',
                  style: AppText.bodySm(r, color: dueColor).copyWith(
                      fontWeight: dueWeight)),
              Text(_assignee, style: AppText.bodySm(r)),
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

class HomeTabItem {
  const HomeTabItem({
    required this.label,
    required this.icon,
    this.activeIcon,
    this.badge = 0,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData? activeIcon;

  /// 未読などの件数。0なら出さない。
  final int badge;
  final VoidCallback? onTap;
}

/// TabBar：4項目＋中央の主操作（brand 塗りの丸。画面に1つ）。
/// 現在地は塗りアイコン＋太字＋ink、他は ink-muted。
class HomeTabBar extends StatelessWidget {
  const HomeTabBar({
    super.key,
    required this.left,
    required this.right,
    required this.center,
    this.activeLeft,
  });

  final List<HomeTabItem> left;
  final List<HomeTabItem> right;
  final HomeTabItem center;

  /// 現在地（left の位置）。
  final int? activeLeft;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface200,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: r.y(64),
          child: Row(
            children: [
              for (var i = 0; i < left.length; i++)
                Expanded(child: _Tab(item: left[i], active: i == activeLeft)),
              Expanded(child: _Center(item: center)),
              for (final t in right)
                Expanded(child: _Tab(item: t, active: false)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.active});

  final HomeTabItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final color = active ? AppColors.ink : AppColors.inkMuted;
    return Semantics(
      button: true,
      selected: active,
      label: item.badge > 0 ? '${item.label} 未読${item.badge}件' : item.label,
      child: InkWell(
        onTap: item.onTap,
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: item.badge > 0,
                backgroundColor: AppColors.amber,
                textColor: AppColors.onAmber,
                label: Text(item.badge > 99 ? '99+' : '${item.badge}'),
                child: Icon(
                    active ? (item.activeIcon ?? item.icon) : item.icon,
                    size: r.x(AppSpace.s6),
                    color: color),
              ),
              SizedBox(height: r.y(AppSpace.s1)),
              Text(item.label,
                  style: AppText.label(r, color: color).copyWith(
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Center extends StatelessWidget {
  const _Center({required this.item});

  final HomeTabItem item;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Semantics(
      button: true,
      label: item.label,
      child: InkWell(
        onTap: item.onTap,
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: r.x(AppSpace.s8 + AppSpace.s2),
                height: r.x(AppSpace.s8 + AppSpace.s2),
                decoration: const BoxDecoration(
                    color: AppColors.blue, shape: BoxShape.circle),
                child: Icon(item.icon,
                    size: r.x(AppSpace.s6), color: AppColors.onBlue),
              ),
              Text(item.label,
                  style: AppText.label(r, color: AppColors.blue)),
            ],
          ),
        ),
      ),
    );
  }
}
