import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 文字の大きさ。「小」が従来（標準）の大きさで、「中」は1.5倍、「大」は2倍。
enum TextSizeLevel {
  small('小', 1.0),
  medium('中', 1.5),
  large('大', 2.0);

  const TextSizeLevel(this.label, this.scale);
  final String label;
  final double scale;
}

/// 色の組み合わせ（パターン）。対象は white・ink・amber・blue と、面に使うグレー（gray）、
/// 背景（bg）。[standard] が従来の配色で、このとき bg は ink と同じ。
///
/// 役割：
/// - white：画面の文字・線（暗い背景では明るい色、明るい背景では黒）。ink は、その反対の色
///   （白い面・琥珀の面に載せる文字、ドロワーなどの濃い面）。
/// - bg：画面・ダイアログの背景。gray：カード・入力欄などの面。
/// - onBlue／onAmber：青・琥珀で塗った面（ボタン・バッジ）の上の文字。
/// - deep：メインカード・ドロワーのグラデーションの濃い側。
/// 値は docs/design-system/tokens.json の palettes と同じ。
enum AppPalette {
  standard(
    label: 'デフォルト',
    note: '黒 × 青 × 琥珀',
    white: Color(0xFFF5F5F5),
    ink: Color(0xFF1A1D20),
    amber: Color(0xFFD97706),
    blue: Color(0xFF0052CC),
    bg: Color(0xFF1A1D20),
    // 白 8%（半透明）。従来の `white.withValues(alpha: 0.08)` と同じ値。
    gray: Color.from(
        alpha: 0.08, red: 245 / 255, green: 245 / 255, blue: 245 / 255),
    deep: Color(0xFF1A1D20),
    onBlue: Color(0xFFF5F5F5),
    onAmber: Color(0xFF1A1D20),
    badgeOnAmber: Color(0xFFF5F5F5),
    onDark: Color(0xFFF5F5F5),
    onLight: Color(0xFF1A1D20),
  ),
  contrast(
    label: 'ハイコントラスト',
    note: '白 × 黒 × 濃い青（明るい背景）',
    white: Color(0xFF000000),
    ink: Color(0xFFFFFFFF),
    amber: Color(0xFFD97706),
    blue: Color(0xFF0044CC),
    bg: Color(0xFFF8FAFC),
    gray: Color.from(alpha: 0.06, red: 0, green: 0, blue: 0),
    deep: Color(0xFF0A1633),
    onBlue: Color(0xFFFFFFFF),
    onAmber: Color(0xFF000000),
    badgeOnAmber: Color(0xFF000000),
    onDark: Color(0xFFFFFFFF),
    onLight: Color(0xFF000000),
  ),
  ocean(
    label: 'オーシャン',
    note: '明るい紺 × 空色 × 橙',
    white: Color(0xFFFFFFFF),
    ink: Color(0xFF0A192F),
    amber: Color(0xFFFF9F1C),
    blue: Color(0xFF0284C7),
    bg: Color(0xFF1E3A5F),
    gray: Color.from(alpha: 0.10, red: 1, green: 1, blue: 1),
    deep: Color(0xFF0A192F),
    onBlue: Color(0xFF0A192F),
    onAmber: Color(0xFF0A192F),
    badgeOnAmber: Color(0xFF0A192F),
    onDark: Color(0xFFFFFFFF),
    onLight: Color(0xFF0A192F),
  ),
  forest(
    label: 'フォレスト',
    note: '明るい緑 × エメラルド × 金',
    white: Color(0xFFF8FAF8),
    ink: Color(0xFF062419),
    amber: Color(0xFFFBBF24),
    blue: Color(0xFF059669),
    bg: Color(0xFF1B3B2B),
    gray: Color.from(alpha: 0.10, red: 1, green: 1, blue: 1),
    deep: Color(0xFF062419),
    onBlue: Color(0xFF062419),
    onAmber: Color(0xFF062419),
    badgeOnAmber: Color(0xFF062419),
    onDark: Color(0xFFF8FAF8),
    onLight: Color(0xFF062419),
  ),
  plum(
    label: 'プラム',
    note: '明るい紫 × すみれ × 黄',
    white: Color(0xFFFAF8FC),
    ink: Color(0xFF1E0B36),
    amber: Color(0xFFFACC15),
    blue: Color(0xFF7C3AED),
    bg: Color(0xFF362447),
    gray: Color.from(alpha: 0.10, red: 1, green: 1, blue: 1),
    deep: Color(0xFF1E0B36),
    onBlue: Color(0xFFFAF8FC),
    onAmber: Color(0xFF1E0B36),
    badgeOnAmber: Color(0xFF1E0B36),
    onDark: Color(0xFFFAF8FC),
    onLight: Color(0xFF1E0B36),
  );

  const AppPalette({
    required this.label,
    required this.note,
    required this.white,
    required this.ink,
    required this.amber,
    required this.blue,
    required this.bg,
    required this.gray,
    required this.deep,
    required this.onBlue,
    required this.onAmber,
    required this.badgeOnAmber,
    required this.onDark,
    required this.onLight,
  });

  final String label;
  final String note;
  final Color white;
  final Color ink;
  final Color amber;
  final Color blue;

  /// 画面・ダイアログの背景。
  final Color bg;

  /// 面（カード・入力欄の背景など）に使うグレー。
  final Color gray;

  /// グラデーションの濃い側（メインカード・ドロワー）。
  final Color deep;

  /// 青・琥珀の面の上の文字。
  final Color onBlue;
  final Color onAmber;

  /// 琥珀で塗った小さなバッジ（ダッシュボードのカード）の文字。デフォルトは従来どおり白。
  final Color badgeOnAmber;

  /// いつも暗い面（動画・黒い背景・赤いバッジ）の上の明るい文字。
  final Color onDark;

  /// いつも白い面（ログインの入力欄）の上の暗い文字。
  final Color onLight;

  /// 明るい背景の配色か。
  bool get isLight => bg.computeLuminance() > 0.5;
}

/// 表示の設定（文字の大きさ・色の組み合わせ・ふりがな）。端末に保存する。
/// 変えると、画面全体を作り直して反映する（[ClipDeskApp] が購読する）。
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const _kText = 'settings.textSize';
  static const _kPalette = 'settings.palette';
  static const _kRuby = 'settings.ruby';

  TextSizeLevel _textSize = TextSizeLevel.small;
  AppPalette _palette = AppPalette.standard;
  bool _ruby = false;

  TextSizeLevel get textSize => _textSize;
  AppPalette get palette => _palette;

  /// 漢字にふりがなを付けるか。
  bool get ruby => _ruby;

  /// 保存済みの設定を読む。読めなければ（初回・失敗）従来の表示のまま。
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _textSize = TextSizeLevel.values.firstWhere(
          (e) => e.name == p.getString(_kText),
          orElse: () => TextSizeLevel.small);
      _palette = AppPalette.values.firstWhere(
          (e) => e.name == p.getString(_kPalette),
          orElse: () => AppPalette.standard);
      _ruby = p.getBool(_kRuby) ?? false;
    } catch (_) {}
  }

  Future<void> setTextSize(TextSizeLevel v) async {
    if (v == _textSize) return;
    _textSize = v;
    notifyListeners();
    await _save((p) => p.setString(_kText, v.name));
  }

  Future<void> setPalette(AppPalette v) async {
    if (v == _palette) return;
    _palette = v;
    notifyListeners();
    await _save((p) => p.setString(_kPalette, v.name));
  }

  Future<void> setRuby(bool v) async {
    if (v == _ruby) return;
    _ruby = v;
    notifyListeners();
    await _save((p) => p.setBool(_kRuby, v));
  }

  /// テスト用：保存せずに、初期の状態へ戻す。
  void resetForTest() {
    _textSize = TextSizeLevel.small;
    _palette = AppPalette.standard;
    _ruby = false;
  }

  Future<void> _save(Future<bool> Function(SharedPreferences) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {}
  }
}
