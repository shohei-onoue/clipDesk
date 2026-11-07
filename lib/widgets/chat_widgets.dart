import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';

/// アシスタントの発言（アバター + 名前 + 吹き出し）。
class AssistantMessage extends StatelessWidget {
  const AssistantMessage({
    super.key,
    this.text,
    this.lines,
    this.showHeader = true,
    this.fixedWidth = false,
  }) : assert(text != null || lines != null);

  final String? text;
  final List<String>? lines;

  /// false のとき、アバターと名前を出さず余白だけ空ける。
  final bool showHeader;

  /// true のとき吹き出しの幅を 280.8/390 に固定する（長文用）。
  final bool fixedWidth;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final style =
        AppText.noto(r.x(18), weight: FontWeight.w400, height: 27 / 18);
    final body = lines != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final l in lines!) Text(l, style: style)],
          )
        : Text(text!, style: style);

    return Padding(
      padding: EdgeInsets.only(bottom: r.y(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: r.x(44),
            height: r.x(44),
            child: showHeader ? const _Avatar() : null,
          ),
          SizedBox(width: r.x(8)),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeader)
                  Padding(
                    padding: EdgeInsets.only(bottom: r.y(4)),
                    child: Text('ナビゲーター',
                        style: AppText.noto(r.x(14), height: 18.2 / 14)),
                  ),
                Container(
                  width: fixedWidth ? r.x(280.8) : null,
                  padding: EdgeInsets.symmetric(
                      horizontal: r.x(16), vertical: r.y(14)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.ink),
                    borderRadius: BorderRadius.circular(r.x(16)),
                  ),
                  child: body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset('assets/navigater.png',
          fit: BoxFit.cover, semanticLabel: 'ナビゲーター'),
    );
  }
}

/// 自分の発言（青い吹き出し・右寄せ）。
class MyMessage extends StatelessWidget {
  const MyMessage(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.only(bottom: r.y(10)),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: r.x(20), vertical: r.y(10)),
          decoration: BoxDecoration(
            color: AppColors.blue,
            borderRadius: BorderRadius.circular(r.x(16)),
          ),
          child: Text(text,
              style:
                  AppText.noto(r.x(18), color: Colors.white, height: 27 / 18)),
        ),
      ),
    );
  }
}

/// 選択肢ボタン。
class AppChip extends StatelessWidget {
  const AppChip(this.label, {super.key, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(r.x(16)),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: r.y(48)),
          padding: EdgeInsets.symmetric(horizontal: r.x(20)),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.ink),
            borderRadius: BorderRadius.circular(r.x(16)),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(label, style: AppText.noto(r.x(16), height: 20.8 / 16)),
          ),
        ),
      ),
    );
  }
}

/// 下寄せで並べ、あふれたらスクロールできる領域。
class BottomAlignedScroll extends StatelessWidget {
  const BottomAlignedScroll({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        reverse: true,
        padding: EdgeInsets.fromLTRB(r.x(20), r.y(4), r.x(20), r.y(12)),
        child: ConstrainedBox(
          constraints:
              BoxConstraints(minHeight: c.maxHeight - r.y(4) - r.y(12)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}
