import 'package:flutter/material.dart' as m;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../core/app_settings.dart';
import '../core/event_age.dart';
import '../core/read_aloud.dart';
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

  /// 読み上げがオンのとき、0.2秒を超える長押しで、この文字を読み上げる（タップだけでは読み上げない）。
  /// 0.2秒以内のタップは、ボタンの操作として働く（読み上げない）。
  Widget _speakable(Widget child) {
    if (!AppSettings.instance.readAloud) return child;
    return _LongPressSpeak(text: semanticsLabel ?? data, child: child);
  }

  @override
  Widget build(BuildContext context) => _speakable(_content(context));

  Widget _content(BuildContext context) {
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
              // 漢字を、まわりの文字と同じベースライン（下ぞろえ）に置く。ふりがなの分、行は上へ高くなる。
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: ExcludeSemantics(
                // 下から上へ積む。Column のベースラインは先頭の子（漢字）のものになる。
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    verticalDirection: VerticalDirection.up,
                    children: [
                      // 文字の大きさの倍率は、外側の Text.rich が WidgetSpan ごと掛けるので、ここでは掛けない
                      // （掛けると二重に大きくなる）。
                      m.Text(s.base,
                          style: base, textScaler: TextScaler.noScaling),
                      m.Text(s.ruby!,
                          style: rubyStyle,
                          maxLines: 1,
                          textScaler: TextScaler.noScaling),
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

/// 読み上げの長押しの長さ。
const readAloudHold = Duration(milliseconds: 200);

/// 指の操作が、アプリに届くまでにたった時間。テストで差し替える。
@visibleForTesting
Duration Function(Duration timeStamp) readAloudEventAge = eventAge;

/// 指が触れてから [readAloudHold] たった時に成立する長押し。
/// Web では触れた合図が遅れて届くことがあるため、届くまでの時間を引いて待つ。
/// 引かないと、長押しと判定するまでが約0.4秒になる。
class _ReadAloudPress extends LongPressGestureRecognizer {
  _ReadAloudPress() : super(duration: readAloudHold);

  Duration _wait = readAloudHold;

  @override
  Duration get deadline => _wait;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    final left = readAloudHold - readAloudEventAge(event.timeStamp);
    _wait = left.isNegative ? Duration.zero : left;
    super.addAllowedPointer(event);
  }
}

class _LongPressSpeak extends StatelessWidget {
  const _LongPressSpeak({required this.text, required this.child});
  final String text;
  final Widget child;

  /// 0.2秒以内のタップは、ボタンの操作（画面遷移・ダイアログ）として働く。
  /// 0.2秒を超える長押しになった時点で読み上げに切り替わり、ボタンの操作は働かない。
  /// 指を動かした（スクロール）ときは、どちらにもならない。
  @override
  Widget build(BuildContext context) {
    void speak() => ReadAloud.instance.speak(text);
    return RawGestureDetector(
      gestures: {
        _ReadAloudPress: GestureRecognizerFactoryWithHandlers<_ReadAloudPress>(
          _ReadAloudPress.new,
          (r) => r.onLongPress = speak,
        ),
      },
      semantics: _SpeakSemantics(speak),
      child: child,
    );
  }
}

/// 画面読み上げ機能の「長押し」でも読み上げる。
class _SpeakSemantics extends SemanticsGestureDelegate {
  const _SpeakSemantics(this.speak);
  final VoidCallback speak;

  @override
  void assignSemantics(RenderSemanticsGestureHandler renderObject) =>
      renderObject.onLongPress = speak;
}
