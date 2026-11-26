import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;

import '../core/app_colors.dart';
import '../core/part_colors.dart';
import '../core/app_settings.dart';
import '../core/app_text.dart';
import '../core/night_theme.dart';
import '../core/read_aloud.dart';
import '../core/responsive.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/ruby_text.dart';

/// 設定画面（Figma 421:3）。文字の大きさ（x1.0・x1.5・x2.0）、色の組み合わせ（5パターン）、
/// ふりがなの表示、音声読み上げを切り替える。
/// 変更はすぐ画面全体に反映され、端末に保存される。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final s = AppSettings.instance;
    return Theme(
      data: nightTheme,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        drawer: const AppDrawer(),
        drawerScrimColor: const Color(0x8A000000),
        body: SafeArea(
          child: Column(
            children: [
              const AppHeader(title: '設定'),
              Expanded(
                child: ListView(
                  padding:
                      EdgeInsets.fromLTRB(r.x(14), r.x(14), r.x(14), r.x(24)),
                  children: [
                    _Section(
                      title: '文字の大きさ',
                      child: Column(children: [
                        Row(children: [
                          for (final level in TextSizeLevel.values) ...[
                            if (level != TextSizeLevel.small)
                              SizedBox(width: r.x(8)),
                            Expanded(
                              child: _Choice(
                                scale: level.scale,
                                selected: s.textSize == level,
                                onTap: () => s.setTextSize(level),
                              ),
                            ),
                          ],
                        ]),
                        SizedBox(height: r.x(12)),
                        _Preview(),
                      ]),
                    ),
                    SizedBox(height: r.x(16)),
                    _Section(
                      title: '色の組み合わせ',
                      child: Column(children: [
                        for (final p in AppPalette.values) ...[
                          _PaletteTile(
                            palette: p,
                            selected: s.palette == p,
                            onTap: () => s.setPalette(p),
                          ),
                          if (p != AppPalette.values.last)
                            SizedBox(height: r.x(8)),
                        ],
                      ]),
                    ),
                    SizedBox(height: r.x(16)),
                    // 見出しは出さず、スイッチの行だけ。行の上下の余白と合わせて、高さをそろえる。
                    _Section(
                      top: 6,
                      bottom: 6,
                      child: _SwitchRow(
                        label: 'ふりがなを表示',
                        value: s.ruby,
                        onChanged: s.setRuby,
                      ),
                    ),
                    SizedBox(height: r.x(16)),
                    _Section(
                      top: 6,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 見出しの右に、読み上げのスイッチを置く。
                            _SwitchRow(
                              label: '音声読み上げ',
                              value: s.readAloud,
                              onChanged: s.setReadAloud,
                            ),
                            SizedBox(height: r.x(6)),
                            Text('読み上げ速さ', style: AppText.dark(r.x(16))),
                            Semantics(
                              label: '読み上げ速さ',
                              value: ReadSpeed.label(s.readSpeed),
                              child: Slider(
                                value: s.readSpeed,
                                min: ReadSpeed.min,
                                max: ReadSpeed.max,
                                divisions: ReadSpeed.divisions,
                                activeColor: AppColors.blue,
                                inactiveColor: AppColors.gray,
                                // 動かして止めた位置で、その速さで試しに読み上げる
                                // （指を離す前でも、止めたら読む。離したときはすぐ読む）。
                                onChanged: (v) {
                                  s.setReadSpeed(v);
                                  ReadAloud.instance
                                      .speakAfterPause('この速さで読み上げます。');
                                },
                                onChangeEnd: (_) =>
                                    ReadAloud.instance.speakNow('この速さで読み上げます。'),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('ゆっくり', style: AppText.dark(r.x(12))),
                                Text('はやい', style: AppText.dark(r.x(12))),
                              ],
                            ),
                          ]),
                    ),
                  ],
                ),
              ),
              _SaveBar(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 画面下の保存ボタン。押すと、いまの設定をログイン中のユーザーの設定として保存する。
class _SaveBar extends StatefulWidget {
  @override
  State<_SaveBar> createState() => _SaveBarState();
}

class _SaveBarState extends State<_SaveBar> {
  bool _busy = false;
  String? _result;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    final ok = await AppSettings.instance.saveForUser();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = ok
          ? '保存しました。次にログインしたときも、この設定になります。'
          : '保存できませんでした。通信を確認して、もう一度お試しください。';
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final unsaved = AppSettings.instance.unsaved;
    final note =
        _result ?? (unsaved ? '変更はまだ保存していません。保存すると、あなたの設定として残ります。' : null);
    final canSave = !_busy && unsaved;
    return Container(
      padding: EdgeInsets.fromLTRB(r.x(14), r.x(10), r.x(14), r.x(12)),
      decoration: BoxDecoration(
        color: AppColors.ink,
        border: Border(
            top: BorderSide(color: AppColors.white.withValues(alpha: 0.16))),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (note != null) ...[
          Text(note,
              style: AppText.dark(r.x(13),
                  weight: FontWeight.w400,
                  color: AppColors.white.withValues(alpha: 0.7),
                  height: 1.5)),
          SizedBox(height: r.x(8)),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: canSave ? _save : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: PartColors.saveButtonText,
              disabledBackgroundColor: AppColors.white.withValues(alpha: 0.16),
              disabledForegroundColor: AppColors.white.withValues(alpha: 0.7),
              minimumSize: Size.fromHeight(r.x(56)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.x(10))),
            ),
            child: Text(_busy ? '保存しています…' : '設定を保存する',
                // 文字の色は style で決まる（押せないときは、画面の文字の色）。
                style: AppText.dark(r.x(18),
                    color: canSave ? PartColors.saveButtonText : null)),
          ),
        ),
      ]),
    );
  }
}

/// 設定のまとまり（情報面のカード）。見出しは省略できる。
class _Section extends StatelessWidget {
  const _Section(
      {this.title, required this.child, this.top = 14, this.bottom = 14});
  final String? title;
  final Widget child;

  /// 内側の上下の余白。左右は14。
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(r.x(14), r.x(top), r.x(14), r.x(bottom)),
      decoration: BoxDecoration(
        color: AppColors.gray,
        border: Border.all(color: AppColors.white.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(r.x(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: AppText.dark(r.x(18))),
            SizedBox(height: r.x(16)),
          ],
          child,
        ],
      ),
    );
  }
}

/// 文字の大きさの選択ボタン（x1.0・x1.5・x2.0）。選択中は blue 塗り、ほかは枠だけ。
class _Choice extends StatelessWidget {
  const _Choice(
      {required this.scale, required this.selected, required this.onTap});
  final double scale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final times = scale.toStringAsFixed(1);
    return Semantics(
      button: true,
      selected: selected,
      label: '文字の大きさ$times倍',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: r.x(56)),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.blue : null,
            border: selected
                ? null
                : Border.all(color: AppColors.white.withValues(alpha: 0.55)),
            borderRadius: BorderRadius.circular(r.x(10)),
          ),
          child: ExcludeSemantics(
            child: Text('x$times',
                semanticsLabel: '$times倍',
                style: AppText.dark(r.x(18),
                    color: selected
                        ? AppColors.on(AppColors.blue)
                        : AppColors.white.withValues(alpha: 0.7))),
          ),
        ),
      ),
    );
  }
}

/// 文字の大きさの見本。いまの設定（大きさ・色・ふりがな）で表示される。
class _Preview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.x(12)),
      decoration: BoxDecoration(
        color: AppColors.ink,
        border: Border.all(color: AppColors.white.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(r.x(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('見本', style: AppText.dark(r.x(12), color: AppColors.amber)),
          SizedBox(height: r.x(4)),
          Text('動画編集の依頼を確認します。',
              style: AppText.dark(r.x(14),
                  weight: FontWeight.w400, height: 24 / 14)),
        ],
      ),
    );
  }
}

/// 色の組み合わせ1つ分。5色の見本（背景・白・琥珀・青・グレー）と名前を並べる。
class _PaletteTile extends StatelessWidget {
  const _PaletteTile(
      {required this.palette, required this.selected, required this.onTap});
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Semantics(
      button: true,
      selected: selected,
      label: '色の組み合わせ ${palette.label}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(r.x(12)),
          decoration: BoxDecoration(
            color: palette.ink,
            border: Border.all(
              color: selected
                  ? AppColors.blue
                  : AppColors.white.withValues(alpha: 0.55),
              width: selected ? 3 : 1,
            ),
            borderRadius: BorderRadius.circular(r.x(12)),
          ),
          child: ExcludeSemantics(
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(palette.label,
                        style: AppText.dark(r.x(16), color: palette.white)),
                    SizedBox(height: r.x(10)),
                    // 5色の見本：白・黒（背景）・琥珀・青・グレー。
                    Row(children: [
                      _Swatch(palette.white, ring: palette.white),
                      _Swatch(palette.ink, ring: palette.white),
                      _Swatch(palette.amber, ring: palette.white),
                      _Swatch(palette.blue, ring: palette.white),
                      _Swatch(Color.alphaBlend(palette.gray, palette.ink),
                          ring: palette.white),
                    ]),
                  ],
                ),
              ),
              SizedBox(width: r.x(8)),
              if (selected)
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.x(10), vertical: r.x(6)),
                  decoration: BoxDecoration(
                    color: palette.blue,
                    borderRadius: BorderRadius.circular(r.x(8)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check,
                        size: r.x(16), color: palette.on(palette.blue)),
                    SizedBox(width: r.x(4)),
                    Text('選択中',
                        style: AppText.dark(r.x(12),
                            color: palette.on(palette.blue))),
                  ]),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color, {required this.ring});
  final Color color;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      width: r.x(24),
      height: r.x(24),
      margin: EdgeInsets.only(right: r.x(6)),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: ring.withValues(alpha: 0.55)),
      ),
    );
  }
}

/// オン・オフの切り替え（ふりがな・音声読み上げ）。左に見出し、右にスイッチ。下の端をそろえる。
class _SwitchRow extends StatelessWidget {
  const _SwitchRow(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    // 押せるのはスイッチの部分だけ。文字をタップしたときは、音声読み上げ（オンのとき）だけが働く。
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        // スイッチ（高さ48）の絵の下には8の余白がある。字は枠の下から文字の大きさの約0.21上にあるので、
        // その分を引いて持ち上げ、文字が大きくてもスイッチと下の位置がずれないようにする。
        child: Padding(
          padding: EdgeInsets.only(
              top: 8, bottom: math.max(0, 12 - r.tx(18) * 0.21)),
          child: Text(label, style: AppText.dark(r.x(18))),
        ),
      ),
      SizedBox(width: r.x(8)),
      Semantics(
        toggled: value,
        label: label,
        child: Switch(
          padding: EdgeInsets.zero,
          // パソコンのブラウザでも高さを48にする（押しやすさと、文字との下ぞろえのため）。
          materialTapTargetSize: MaterialTapTargetSize.padded,
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.on(PartColors.toggleFill),
          activeTrackColor: PartColors.toggleFill,
          inactiveThumbColor: AppColors.white.withValues(alpha: 0.7),
          inactiveTrackColor: AppColors.gray,
        ),
      ),
    ]);
  }
}
