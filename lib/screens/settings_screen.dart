import 'package:flutter/material.dart' hide Text;

import '../core/app_colors.dart';
import '../core/app_settings.dart';
import '../core/app_text.dart';
import '../core/night_theme.dart';
import '../core/read_aloud.dart';
import '../core/responsive.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/ruby_text.dart';

/// 設定画面。文字の大きさ（小・中・大）、色の組み合わせ（5パターン）、ふりがなの表示を切り替える。
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
        backgroundColor: AppColors.bg,
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
                      note: '「小」が標準です。「中」は1.5倍、「大」は2倍になります。',
                      child: Column(children: [
                        Row(children: [
                          for (final level in TextSizeLevel.values) ...[
                            if (level != TextSizeLevel.small)
                              SizedBox(width: r.x(8)),
                            Expanded(
                              child: _Choice(
                                label: level.label,
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
                      note: '背景・文字・強調・操作・面の色をまとめて変えます。',
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
                    _Section(
                      title: 'ふりがな',
                      note: '漢字の上に、ふりがなを表示します。利用者が入力した名前などには付きません。',
                      child: _RubySwitch(
                        label: 'ふりがなを表示する',
                        value: s.ruby,
                        onChanged: s.setRuby,
                      ),
                    ),
                    SizedBox(height: r.x(16)),
                    _Section(
                      title: '音声読み上げ',
                      note: 'オンにすると、画面の文字をタップしたとき、その文字を声で読み上げます。',
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _RubySwitch(
                              label: '音声で読み上げる',
                              value: s.readAloud,
                              onChanged: s.setReadAloud,
                            ),
                            SizedBox(height: r.x(14)),
                            Text('読み上げの速さ', style: AppText.dark(r.x(16))),
                            SizedBox(height: r.x(8)),
                            Row(children: [
                              for (final sp in ReadSpeed.values) ...[
                                if (sp != ReadSpeed.slow)
                                  SizedBox(width: r.x(8)),
                                Expanded(
                                  child: _Choice(
                                    label: sp.label,
                                    what: '読み上げの速さ',
                                    selected: s.readSpeed == sp,
                                    onTap: () async {
                                      await s.setReadSpeed(sp);
                                      ReadAloud.instance.speak('この速さで読み上げます。');
                                    },
                                  ),
                                ),
                              ],
                            ]),
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
    final note = _result ??
        (unsaved ? '変更はまだ保存していません。保存すると、あなたの設定として残ります。' : '変更はありません。');
    return Container(
      padding: EdgeInsets.fromLTRB(r.x(14), r.x(10), r.x(14), r.x(12)),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(
            top: BorderSide(color: AppColors.white.withValues(alpha: 0.16))),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(note,
            style: AppText.dark(r.x(13),
                weight: FontWeight.w400,
                color: AppColors.white.withValues(alpha: 0.7),
                height: 1.5)),
        SizedBox(height: r.x(8)),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy || !unsaved ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: AppColors.ink,
              disabledBackgroundColor: AppColors.white.withValues(alpha: 0.16),
              disabledForegroundColor: AppColors.white.withValues(alpha: 0.7),
              minimumSize: Size.fromHeight(r.x(56)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.x(10))),
            ),
            child: Text(_busy ? '保存しています…' : '設定を保存する',
                style: AppText.dark(r.x(18), color: null)),
          ),
        ),
      ]),
    );
  }
}

/// 見出し・説明つきの設定のまとまり（情報面のカード）。
class _Section extends StatelessWidget {
  const _Section(
      {required this.title, required this.note, required this.child});
  final String title;
  final String note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.x(14)),
      decoration: BoxDecoration(
        color: AppColors.gray,
        border: Border.all(color: AppColors.white.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(r.x(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.dark(r.x(18))),
          SizedBox(height: r.x(4)),
          Text(note,
              style: AppText.dark(r.x(13),
                  weight: FontWeight.w400,
                  color: AppColors.white.withValues(alpha: 0.7),
                  height: 1.5)),
          SizedBox(height: r.x(12)),
          child,
        ],
      ),
    );
  }
}

/// 選択ボタン（小・中・大）。選択中は blue 塗り＋「選択中」の語句＋チェック。
class _Choice extends StatelessWidget {
  const _Choice(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.what = '文字の大きさ'});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String what;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Semantics(
      button: true,
      selected: selected,
      label: '$what$label',
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
            child: Text(label,
                style: AppText.dark(r.x(18),
                    color: selected
                        ? AppColors.onBlue
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
        color: AppColors.bg,
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
            color: palette.bg,
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
                    SizedBox(height: r.x(2)),
                    Text(palette.note,
                        style: AppText.dark(r.x(12),
                            weight: FontWeight.w400,
                            color: palette.white.withValues(alpha: 0.7))),
                    SizedBox(height: r.x(8)),
                    // 5色の見本：白・黒（背景）・琥珀・青・グレー。
                    Row(children: [
                      _Swatch(palette.white, ring: palette.white),
                      _Swatch(palette.bg, ring: palette.white),
                      _Swatch(palette.amber, ring: palette.white),
                      _Swatch(palette.blue, ring: palette.white),
                      _Swatch(Color.alphaBlend(palette.gray, palette.bg),
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
                    Icon(Icons.check, size: r.x(16), color: palette.onBlue),
                    SizedBox(width: r.x(4)),
                    Text('選択中',
                        style: AppText.dark(r.x(12), color: palette.onBlue)),
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

/// オン・オフの切り替え（ふりがな・音声読み上げ）。「オン」「オフ」の語句も添える。
class _RubySwitch extends StatelessWidget {
  const _RubySwitch(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    // 押せるのはスイッチの部分だけ。文字をタップしたときは、音声読み上げ（オンのとき）だけが働く。
    return Row(children: [
      Expanded(
        child: Text('$label（${value ? 'オン' : 'オフ'}）',
            style: AppText.dark(r.x(16))),
      ),
      SizedBox(width: r.x(8)),
      Semantics(
        toggled: value,
        label: label,
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.onBlue,
          activeTrackColor: AppColors.blue,
          inactiveThumbColor: AppColors.white.withValues(alpha: 0.7),
          inactiveTrackColor: AppColors.gray,
        ),
      ),
    ]);
  }
}
