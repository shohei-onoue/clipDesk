import 'package:flutter/material.dart' as m;
import 'package:flutter/widgets.dart';

import '../core/app_settings.dart';
import '../core/ruby_dictionary.dart';

/// アプリ全体で使う文字の部品。標準の `Text` と同じ使い方で、設定でふりがなを「オン」にすると、
/// 辞書（[rubyEntries]）にある漢字の上に、ふりがな（ルビ）を小さく表示する。
/// 「オフ」のときは、標準の `Text` をそのまま使う（見た目は従来と同じ）。
///
/// 使うファイルでは、標準の Text を隠してこちらを読み込む：
/// `import 'package:flutter/material.dart' hide Text;` ＋ `import '.../widgets/ruby_text.dart';`
class Text extends StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.ruby = true,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  /// false なら、設定がオンでもふりがなを付けない（すでに手でふりがなを付けている箇所用）。
  final bool ruby;

  @override
  Widget build(BuildContext context) {
    final plain = m.Text(
      data,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
    if (!ruby || !AppSettings.instance.ruby || !RubyDictionary.hasKanji(data)) {
      return plain;
    }
    final segments = RubyDictionary.segment(data);
    if (segments.every((s) => s.ruby == null)) return plain;

    final base = DefaultTextStyle.of(context).style.merge(style);
    final size = base.fontSize ?? 14;
    final rubyStyle = base.copyWith(
      fontSize: size * 0.5,
      fontWeight: FontWeight.w500,
      height: 1.0,
      letterSpacing: 0,
    );
    return m.Text.rich(
      TextSpan(children: [
        for (final s in segments)
          if (s.ruby == null)
            TextSpan(text: s.base)
          else
            WidgetSpan(
              // 下をそろえる：ふりがなの分、行が上へ高くなる。
              alignment: PlaceholderAlignment.bottom,
              child: ExcludeSemantics(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // 文字の大きさの倍率は、外側の Text.rich が WidgetSpan ごと掛けるので、ここでは掛けない
                  // （掛けると二重に大きくなる）。
                  m.Text(s.ruby!,
                      style: rubyStyle,
                      maxLines: 1,
                      textScaler: TextScaler.noScaling),
                  m.Text(s.base, style: base, textScaler: TextScaler.noScaling),
                ]),
              ),
            ),
      ]),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel ?? data,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
