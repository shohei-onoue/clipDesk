import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 起動時オープニング（OLDROOKIE）の長さ。この秒数から先は最終画面。
const introEnd = 18.2;

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _lerp(double a, double b, double t) => a + (b - a) * t;

double _cubic(double x1, double y1, double x2, double y2, double t) {
  if (t <= 0) return 0;
  if (t >= 1) return 1;
  final cx = 3 * x1;
  final bx = 3 * (x2 - x1) - cx;
  final ax = 1 - cx - bx;
  final cy = 3 * y1;
  final by = 3 * (y2 - y1) - cy;
  final ay = 1 - cy - by;
  var u = t;
  for (var i = 0; i < 6; i++) {
    final x = ((ax * u + bx) * u + cx) * u - t;
    if (x.abs() < 1e-5) break;
    final d = (3 * ax * u + 2 * bx) * u + cx;
    if (d.abs() < 1e-5) break;
    u -= x / d;
  }
  return ((ay * u + by) * u + cy) * u;
}

double _snap(double t) => _cubic(0.2, 0.9, 0.2, 1.0, _clamp01(t));

/// 最終画面のタイトル（OLDROOKIE / Clip Desk）の縦の中心。
/// ログインフォームの「Clip Desk」と同じ位置（画面の中心から121px上）。
double _titleY(double h) => h * 0.5 - 121;

double _outBack(double t, [double s = 1.70158]) {
  final p = _clamp01(t) - 1;
  return p * p * ((s + 1) * p + s) + 1;
}

/// 冒頭の OLDROOKIE を3秒にしたぶん（元の1.5秒より1.5秒長い）、以降の場面を後ろへずらす。
const _shift = 1.5;

class _Metrics {
  _Metrics(this.total, this.advances, this.tracking);
  final double total;
  final List<double> advances;
  final double tracking;
}

/// 最終画面の「Clip Desk」とサブタイトル用の書体（Figma: Oswald Bold）。
const _oswald = 'Oswald';

/// Figma と同じく、単語の間は半角スペース2つ。
const _subtitle = 'MOVIE  EDITING  INSTRUCTIONS';

TextPainter _glyph(
  String ch,
  double size,
  Paint? fg,
  Color? color, [
  String family = _oswald,
]) =>
    TextPainter(
      text: TextSpan(
        text: ch,
        style: TextStyle(
          fontFamily: family,
          fontVariations:
              family == _oswald ? const [FontVariation('wght', 700)] : null,
          fontWeight: FontWeight.w700,
          fontSize: size,
          height: 1.0,
          color: fg == null ? color : null,
          foreground: fg,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

_Metrics _measure(
  String text,
  double size,
  double ratio, [
  String family = _oswald,
]) {
  final tracking = size * ratio;
  var total = 0.0;
  final adv = <double>[];
  for (var i = 0; i < text.length; i++) {
    final w = _glyph(text[i], size, null, Colors.black, family).width;
    adv.add(w);
    total += w + (i < text.length - 1 ? tracking : 0);
  }
  return _Metrics(total, adv, tracking);
}

double _fitted(String text, double targetW, double ratio) {
  const base = 100.0;
  return targetW / _measure(text, base, ratio).total * base;
}

/// INSTRUCTIONS を基準の大きさにして、短い単語は文字の間隔を広げ、3行とも同じ幅・同じ高さにそろえる。
double _justRatio(String text, double targetW) {
  final size = _fitted('INSTRUCTIONS', targetW, 0.07);
  final sum = _measure(text, size, 0).total;
  return (targetW - sum) / ((text.length - 1) * size);
}

/// ログインフォームの「Clip Desk」を、オープニング最後の「Clip Desk」と揃えるための値。
/// 文字サイズ（画面幅 w に対する実寸）。
double introTitleSize(double w) => _titleSize(w);

/// 同じく、タイトルの縦の中心（画面の高さ h に対する実寸）。
double introTitleCenterY(double h) => _titleY(h);

/// 最終画面のタイトル（OLDROOKIE / Clip Desk 共通）の文字サイズ。
/// 幅の80%に収めた OLDROOKIE の大きさ（390px幅で約58px）。
double _titleSize(double w) => _fitted('OLDROOKIE', w * 0.8, 0.08);

/// 幅いっぱいに合わせた OLDROOKIE と同じ文字の大きさにするための倍率。
/// Clip Desk の p のしっぽが、下のサブタイトルに重ならない大きさになる。
double _sameSize(String text, double targetW) =>
    _fitted('OLDROOKIE', targetW, 0.08) / _fitted(text, targetW, 0.08);

double _charOffset(
  String text,
  double targetW,
  double ratio,
  int index,
  double stem,
) {
  final size = _fitted(text, targetW, ratio);
  final m = _measure(text, size, ratio);
  var x = -m.total * 0.5;
  for (var i = 0; i < index; i++) {
    x += m.advances[i] + m.tracking;
  }
  return x + m.advances[index] * stem;
}

/// HTML版の「文字の形に動画をくり抜く」オープニング。
/// 白い面から文字の形を抜き（dstOut）、後ろの動画を見せる。
class IntroPainter extends CustomPainter {
  IntroPainter(this.time, this.hide)
      : super(repaint: Listenable.merge([time, hide]));

  final ValueListenable<double> time;

  /// 0＝最終画面の文字を表示、1＝消す（ログインフォームを開いたとき）。
  final ValueListenable<double> hide;

  late double _w;
  late double _h;
  late Canvas _c;

  @override
  void paint(Canvas canvas, Size size) {
    _c = canvas;
    _w = size.width;
    _h = size.height;
    final t = time.value;
    if (t >= introEnd) {
      _paintFinal(t);
    } else {
      // 白い面から文字を抜く表現。11.5秒（時間割u）の瞬間に、
      // 見た目が同じまま「背景は動画のまま、文字を白で塗る」表現に切り替わる。
      final u = t - _shift;
      if (u < 11.5) {
        canvas.saveLayer(Offset.zero & size, Paint());
        canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
        _paintMask(t);
        canvas.restore();
      } else {
        _paintFilled(u);
      }
    }
  }

  Paint _cut(double alpha) => Paint()
    ..color = Color.fromRGBO(0, 0, 0, _clamp01(alpha))
    ..blendMode = BlendMode.dstOut;

  void _fillCut(Rect r, double alpha) => _c.drawRect(r, _cut(alpha));

  void _text(
    String text,
    double cx,
    double cy,
    double targetW,
    double ratio, {
    double scale = 1,
    double alphaL = 1,
    double alphaR = 1,
    double Function(int)? stagger,
    Paint Function(double alpha)? paintFor,
    String family = _oswald,
    double? fixedSize,
    double? absSize,
  }) {
    // absSize は画面上の実寸。fixedSize は 390px 幅のデザイン値で、画面幅に比例させる。
    final size = absSize ??
        (fixedSize != null
            ? fixedSize * _w / 390
            : _fitted(text, targetW, ratio) * scale);
    final m = _measure(text, size, ratio, family);
    var x = cx - m.total * 0.5;
    for (var i = 0; i < text.length; i++) {
      final cw = m.advances[i];
      final r = text.length > 1 ? i / (text.length - 1) : 0.0;
      var a = _lerp(alphaL, alphaR, r);
      var dy = 0.0;
      if (stagger != null) {
        final sp = stagger(i);
        if (sp <= 0) {
          x += cw + m.tracking;
          continue;
        }
        dy = (1 - _outBack(sp, 1.65)) * (size * 0.95);
        a *= _snap(math.min(1.0, sp * 1.8));
      }
      if (text[i] != ' ' && a > 0.001) {
        final fg = (paintFor ?? _cut)(a);
        final tp = _glyph(text[i], size, fg, null, family);
        tp.paint(_c, Offset(x, cy + dy - tp.height / 2));
      }
      x += cw + m.tracking;
    }
  }

  void _paintMask(double t) {
    final w = _w;
    final h = _h;
    final tw = w * 0.8;
    final cy = h * 0.5;

    // 0–1.0s：全画面の動画。1.0–4.0s：ズームイン終了時と同じ大きさのRの枠から、全体へ収束（3秒）
    if (t < 1.0) {
      _fillCut(Rect.fromLTWH(0, 0, w, h), 1);
    } else if (t < 4.0) {
      final zp = 1 - _snap((t - 1.0) / 3.0);
      final f = math.pow(zp, 2.4).toDouble();
      final rOffset = _charOffset('OLDROOKIE', tw, 0.08, 3, 0.22);
      _text(
        'OLDROOKIE',
        _lerp(w * 0.5, w * 0.5 - rOffset * 52.0, f),
        cy,
        tw,
        0.08,
        scale: _lerp(1.0, 52.0, f),
      );
      if (zp > 0.45) {
        _fillCut(Rect.fromLTWH(0, 0, w, h), _snap((zp - 0.45) / 0.55));
      }
    }

    // 以降は元の時間割（u）を後ろへずらして使う
    final u = t - _shift;

    if (u >= 2.5 && u < 4.2) {
      final raw = (u - 2.5) / 1.7;
      final zoomPhase = _clamp01(raw / 0.82);
      final whitePhase = _clamp01((raw - 0.82) / 0.18);
      final pZoom = _cubic(0.25, 0.85, 0.35, 1.0, zoomPhase);
      final pWhite = _snap(whitePhase);
      final scale = _lerp(1.0, 52.0, math.pow(pZoom, 2.4).toDouble());
      final rOffset = _charOffset('OLDROOKIE', tw, 0.08, 3, 0.22);
      final finalCX = w * 0.5 - rOffset * 52.0;
      final f = math.pow(pZoom, 2.4).toDouble();
      final cx = _lerp(w * 0.5, finalCX, f);
      final maskAlpha = 1 - pWhite;
      _text(
        'OLDROOKIE',
        cx,
        cy,
        tw,
        0.08,
        scale: scale,
        alphaL: maskAlpha,
        alphaR: maskAlpha,
      );
      if (zoomPhase > 0.45 && maskAlpha > 0) {
        _fillCut(
          Rect.fromLTWH(0, 0, w, h),
          _snap((zoomPhase - 0.45) / 0.55) * maskAlpha,
        );
      }
    }

    if (u >= 4.2 && u < 5.2) {
      final p = _snap(_clamp01((u - 4.2) / 1.8));
      _text(
        'MOVIE',
        w * 0.5,
        cy,
        tw,
        _justRatio('MOVIE', tw),
        scale: _lerp(0.94, 1.0, p),
        alphaL: p,
        alphaR: p * 0.22,
      );
    }

    // MOVIE の次に EDITING、その次に INSTRUCTIONS が入り、上へ積み上がる。
    // INSTRUCTIONS が回り出すと MOVIE と EDITING は消える。
    if (u >= 5.2 && u < 10.6) {
      final capM = _fitted('INSTRUCTIONS', tw, 0.07) * 0.78;
      final capE = capM;
      final capI = capM;
      final g = w * 0.03;
      final yE2 = cy;
      final yM2 = cy - (capE / 2 + g + capM / 2);
      final yE3 = cy - (capI / 2 + g + capE / 2);
      final yM3 = yE3 - (capE / 2 + g + capM / 2);
      final pM = _snap(_clamp01((u - 4.2) / 1.8));
      final slideP = _snap(_clamp01((u - 5.2) / 1.3));
      final inP = _snap(_clamp01((u - 5.95) / 1.0));
      final fade = u >= 9.5 ? 1 - _snap(_clamp01((u - 9.5) / 1.0)) : 1.0;
      if (fade > 0) {
        final yM = _lerp(_lerp(cy, yM2, slideP), yM3, inP);
        final yE = _lerp(yE2, yE3, inP);
        _text(
          'MOVIE',
          w * 0.5,
          yM,
          tw,
          _justRatio('MOVIE', tw),
          scale: _lerp(0.94, 1.0, pM),
          alphaL: fade * pM,
          alphaR: 0.22 * fade * pM,
        );
        _text(
          'EDITING',
          _lerp(w * 1.65, w * 0.5, slideP),
          yE,
          tw,
          _justRatio('EDITING', tw),
          alphaL: fade,
          alphaR: 0.72 * fade,
        );
      }
    }

    if (u >= 5.95 && u < 11.5) {
      final slideInP = _snap(_clamp01((u - 5.95) / 1.0));
      final currentX = _lerp(w * 1.7, w * 0.5, slideInP);
      const zoomStart = 9.5;
      final zoomP = u >= zoomStart
          ? _cubic(0.2, 0.85, 0.2, 1.0, _clamp01((u - zoomStart) / 2.0))
          : 0.0;
      final sample = _fitted('INSTRUCTIONS', tw, 0.07);
      final exact = (h * 2.0 / (sample * 0.78)) * 1.3;
      final cameraScale = _lerp(1.0, exact, zoomP);
      final iOffset = _charOffset('INSTRUCTIONS', tw, 0.07, 8, 0.5);
      final cameraShiftX = -iOffset * exact * zoomP;
      final rotP =
          u >= zoomStart ? _snap(_clamp01((u - zoomStart) / 1.0)) : 0.0;
      _c.save();
      _c.translate(w * 0.5, cy);
      _c.rotate(_lerp(0, -math.pi * 0.5, rotP));
      _c.translate(-w * 0.5, -cy);
      _text(
        'INSTRUCTIONS',
        currentX + cameraShiftX,
        cy,
        tw,
        0.07,
        scale: cameraScale,
        alphaL: 1.0,
        alphaR: 0.85,
      );
      _c.restore();
    }
  }

  /// ズームインした I（横にした帯：縦60%・横は画面いっぱい）の見た目のまま、
  /// 白く塗った O に切り替わり、左へ回りながらズームアウトして OLDROOKIE になる。
  void _paintMorph(double u) {
    final w = _w;
    final h = _h;
    final tw = w * 0.8;
    final cy = h * 0.5;
    Paint fill(double a) =>
        Paint()..color = Colors.white.withValues(alpha: _clamp01(a));
    // 移動・拡大縮小・回転は、すべて同じ進み方（2秒、Iの回転ズームと同じ曲線）。
    // 回転が先に終わって位置だけ調整する、という動きにならないようにそろえる。
    final e = _cubic(0.2, 0.85, 0.2, 1.0, _clamp01((u - 11.5) / 2.0));
    final rOffset = _charOffset('OLDROOKIE', tw, 0.08, 4, 0.5);
    // Oの内側の空洞（横にすると、幅は文字の高さの0.122倍）が、
    // 縦60%・横は画面いっぱいになる大きさから始める。
    // Iの帯と同じ見え方なので、切り替えは見えない（空洞の長さは画面幅の3倍近い）。
    final s0 = h * 0.6 / (0.122 * _fitted('OLDROOKIE', tw, 0.08));
    final s = _lerp(s0, 1.0, e);
    // Oは画面の中心から、最終の位置（OLDROOKIE の中の O）まで直線で動く。
    final oFinal = Offset(w * 0.5 + rOffset, _titleY(h));
    final pos = Offset.lerp(Offset(w * 0.5, cy), oFinal, e)!;
    // Oは右へ90度回った状態から、左へ90度回る。
    _c.save();
    _c.translate(pos.dx, pos.dy);
    _c.rotate(math.pi * 0.5 * (1 - e));
    _c.scale(s);
    _c.translate(-oFinal.dx, -oFinal.dy);
    _text('OLDROOKIE', w * 0.5, _titleY(h), tw, 0.08, paintFor: fill);
    _c.restore();
  }

  /// 背景は動画のまま、文字を白で塗る表現（11.5秒〜）。
  /// OLDROOKIE が整ったあと、白い塗りが透明になり、白い枠線だけが残る。
  void _paintFilled(double u) {
    final w = _w;
    final h = _h;
    final tw = w * 0.8;
    if (u < 13.5) {
      _paintMorph(u);
      return;
    }
    final e = u - 13.5;
    // 横ラインが左から右へ伸びるのに合わせて、文字の白い塗りも左から右へ透明になり、
    // 透明になった側は OLDROOKIE から Clip Desk の枠線に変わる。
    final lineP = _snap(_clamp01((u - 15.7) / 1.0));
    final left = (w - tw) * 0.5;
    final wipeX = left + tw * lineP;
    void lockup(
      Paint Function(double) paintFor, [
      Paint Function(double)? sub,
      String title = 'OLDROOKIE',
    ]) {
      final isClip = title == 'Clip Desk';
      _text(
        title,
        w * 0.5,
        _titleY(h),
        tw,
        isClip ? 0.1 : 0.08,
        scale: isClip ? 1 : _sameSize(title, tw),
        paintFor: paintFor,
        family: _oswald,
        // Clip Desk は OLDROOKIE と同じ文字サイズ・同じ中心の高さにそろえる。
        absSize: isClip ? _titleSize(w) : null,
      );
      _text(
        _subtitle,
        w * 0.5,
        _titleY(h) + h * 0.07,
        tw,
        0.1,
        paintFor: sub ?? paintFor,
        family: _oswald,
        fixedSize: 19.6,
        stagger: (i) => _clamp01((e - 0.2 - i * 0.025) / 0.35),
      );
    }

    // 黒50%のフィルムも、同じタイミングで左から右へかかっていく。
    if (lineP > 0) {
      _c.drawRect(
        Rect.fromLTRB(0, 0, w * lineP, h),
        Paint()..color = const Color(0x80000000),
      );
    }
    Paint fillP(double a) =>
        Paint()..color = Colors.white.withValues(alpha: _clamp01(a));
    Paint strokeP(double a) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: _clamp01(a));
    // 小さいサブタイトルは、枠線を細くする（太いと文字がつぶれる）。
    Paint thinP(double a) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: _clamp01(a));
    _c.save();
    _c.clipRect(Rect.fromLTRB(wipeX, 0, w, h));
    lockup(fillP);
    _c.restore();
    if (lineP > 0) {
      _c.save();
      _c.clipRect(Rect.fromLTRB(0, 0, wipeX, h));
      lockup(strokeP, thinP, 'Clip Desk');
      _c.restore();
      _c.drawRect(
        Rect.fromLTWH(left, _titleY(h) + h * 0.115, tw * lineP, 3),
        Paint()..color = Colors.white,
      );
    }
  }

  /// 17.5秒以降：白い枠線の文字とアンダーライン（ログインフォームが出る頃に消える）。
  void _paintFinal(double t) {
    // 黒50%のフィルム（フォームを開いて文字が消えても、残る）。
    _c.drawRect(
      Rect.fromLTWH(0, 0, _w, _h),
      Paint()..color = const Color(0x80000000),
    );
    final fade = 1 - hide.value;
    if (fade <= 0) return;
    final w = _w;
    final h = _h;
    final tw = w * 0.8;
    Paint stroke(double a) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: _clamp01(a * fade));
    Paint thin(double a) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: _clamp01(a * fade));
    _text(
      'Clip Desk',
      w * 0.5,
      _titleY(h),
      tw,
      0.1,
      paintFor: stroke,
      family: _oswald,
      absSize: _titleSize(w),
    );
    _text(
      _subtitle,
      w * 0.5,
      _titleY(h) + h * 0.07,
      tw,
      0.1,
      paintFor: thin,
      family: _oswald,
      fixedSize: 19.6,
    );
    // ラインは、白い塗りが透明になる間にすでに伸びきっている。
    _c.drawRect(
      Rect.fromLTWH((w - tw) * 0.5, _titleY(h) + h * 0.115, tw, 3),
      Paint()..color = Colors.white.withValues(alpha: fade),
    );
  }

  /// オープニングの最終画面が整い、ログインボタンが現れる区間。
  static const fadeStart = 19.1;
  static const fadeLen = 0.6;

  @override
  bool shouldRepaint(IntroPainter old) => old.time != time || old.hide != hide;
}
