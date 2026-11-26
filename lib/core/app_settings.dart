import 'package:cloud_firestore/cloud_firestore.dart';
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

/// 色の組み合わせ（パターン）。1つの組み合わせが持つ色は5色だけ：white・ink・amber・blue・gray。
/// [standard] が従来の配色。背景・文字色・グラデーションなどは、この5色から決める（下の getter）。
///
/// 役割：
/// - white：画面の文字・線（暗い背景では明るい色、明るい背景では黒）。ink は、その反対の色
///   （画面の背景、白い面・琥珀の面に載せる文字、ドロワーなどの濃い面）。
/// - gray：カード・入力欄などの面。
/// 値は docs/design-system/tokens.json の palettes と同じ。
enum AppPalette {
  standard(
    label: 'デフォルト',
    white: Color(0xFFF5F5F5),
    ink: Color(0xFF1A1D20),
    amber: Color(0xFFD97706),
    blue: Color(0xFF0052CC),
    // 白 8%（半透明）。従来の `white.withValues(alpha: 0.08)` と同じ値。
    gray: Color.from(
        alpha: 0.08, red: 245 / 255, green: 245 / 255, blue: 245 / 255),
  ),
  contrast(
    label: 'ハイコントラスト',
    white: Color(0xFFF5F5F5),
    ink: Color(0xFF121212),
    amber: Color(0xFF40C4FF),
    blue: Color(0xFFFFD600),
    gray: Color(0xFF242424),
  ),
  ocean(
    label: 'クリア・オーシャン',
    white: Color(0xFFF0F4F8),
    ink: Color(0xFF0A192F),
    amber: Color(0xFF64FFDA),
    blue: Color(0xFFFF9100),
    gray: Color(0xFF172A45),
  ),
  forest(
    label: 'フォレスト',
    white: Color(0xFFF4F7F5),
    ink: Color(0xFF0D1F17),
    amber: Color(0xFF69F0AE),
    blue: Color(0xFFFFEA00),
    gray: Color(0xFF1B362A),
  ),
  light(
    label: 'クリーン・ライト',
    white: Color(0xFF111111),
    ink: Color(0xFFF7F5F0),
    amber: Color(0xFFC62828),
    blue: Color(0xFF0052CC),
    gray: Color(0xFFFFFFFF),
  );

  const AppPalette({
    required this.label,
    required this.white,
    required this.ink,
    required this.amber,
    required this.blue,
    required this.gray,
  });

  final String label;
  final Color white;
  final Color ink;
  final Color amber;
  final Color blue;

  /// 面（カード・入力欄の背景など）に使うグレー。
  final Color gray;

  /// 明るい背景の配色か。
  bool get isLight => ink.computeLuminance() > 0.5;

  /// 面の上で読みやすい文字色（white か ink のうち、コントラストが高いほう）。
  Color on(Color surface) {
    final l = surface.computeLuminance();
    final lighter =
        white.computeLuminance() < ink.computeLuminance() ? ink : white;
    final darker = identical(lighter, white) ? ink : white;
    double ratio(Color c) {
      final a = c.computeLuminance();
      return (a > l ? a + 0.05 : l + 0.05) / (a > l ? l + 0.05 : a + 0.05);
    }

    return ratio(lighter) >= ratio(darker) ? lighter : darker;
  }
}

/// 読み上げの速さ（倍率）。1.0 が「ふつう」（従来の速さ）。スライダーで 0.5〜1.5 倍まで変えられる。
class ReadSpeed {
  ReadSpeed._();

  static const double min = 0.5;
  static const double max = 1.5;
  static const double normal = 1.0;

  /// スライダーの刻み（0.1 刻み）。
  static const int divisions = 10;

  /// Web（ブラウザ標準は 1.0 が普通の速さ）用。「ふつう」は 1.25。
  static double webRate(double v) => 1.25 * v;

  /// Android・iOS（0.5 が普通の速さ）用。「ふつう」は 0.55。
  static double appRate(double v) => 0.55 * v;

  /// 画面に出す言葉（例：「ふつう（1.0倍）」）。
  static String label(double v) {
    final x = v.toStringAsFixed(1);
    if ((v - normal).abs() < 0.05) return 'ふつう（$x倍）';
    return v < normal ? 'ゆっくり（$x倍）' : 'はやい（$x倍）';
  }

  static double _clamp(double v) =>
      (v.clamp(min, max) * 10).roundToDouble() / 10;

  /// 保存された値（数、または以前の「slow／normal／fast」）を倍率にする。
  static double parse(Object? v) {
    if (v is num) return _clamp(v.toDouble());
    switch (v) {
      case 'slow':
        return 0.7;
      case 'fast':
        return 1.3;
      default:
        return normal;
    }
  }
}

/// 表示の設定（文字の大きさ・色の組み合わせ・ふりがな）。端末に保存する。
/// 変えると、画面全体を作り直して反映する（[ClipDeskApp] が購読する）。
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const _kText = 'settings.textSize';
  static const _kPalette = 'settings.palette';
  static const _kRuby = 'settings.ruby';
  static const _kRead = 'settings.readAloud';
  static const _kReadSpeed = 'settings.readSpeed';

  TextSizeLevel _textSize = TextSizeLevel.small;
  AppPalette _palette = AppPalette.standard;
  bool _ruby = false;
  bool _readAloud = false;
  double _readSpeed = ReadSpeed.normal;

  /// ログイン中のユーザーの ID。設定はこのユーザーの `users/{uid}.settings` に保存する。
  String? _uid;

  /// 画面で変えたが、まだユーザーの設定として保存していない変更があるか。
  bool _unsaved = false;
  bool get unsaved => _unsaved;

  TextSizeLevel get textSize => _textSize;
  AppPalette get palette => _palette;

  /// 漢字にふりがなを付けるか。
  bool get ruby => _ruby;

  /// 文字をタップしたら読み上げるか。
  bool get readAloud => _readAloud;

  /// 読み上げの速さ。
  double get readSpeed => _readSpeed;

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
      _readAloud = p.getBool(_kRead) ?? false;
      _readSpeed = ReadSpeed.parse(p.get(_kReadSpeed));
    } catch (_) {}
  }

  Future<void> setTextSize(TextSizeLevel v) async {
    if (v == _textSize) return;
    _textSize = v;
    _unsaved = true;
    notifyListeners();
    await _save((p) => p.setString(_kText, v.name));
  }

  Future<void> setPalette(AppPalette v) async {
    if (v == _palette) return;
    _palette = v;
    _unsaved = true;
    notifyListeners();
    await _save((p) => p.setString(_kPalette, v.name));
  }

  Future<void> setRuby(bool v) async {
    if (v == _ruby) return;
    _ruby = v;
    _unsaved = true;
    notifyListeners();
    await _save((p) => p.setBool(_kRuby, v));
  }

  Future<void> setReadAloud(bool v) async {
    if (v == _readAloud) return;
    _readAloud = v;
    _unsaved = true;
    notifyListeners();
    await _save((p) => p.setBool(_kRead, v));
  }

  Future<void> setReadSpeed(double v) async {
    v = ReadSpeed.parse(v);
    if (v == _readSpeed) return;
    _readSpeed = v;
    _unsaved = true;
    notifyListeners();
    await _save((p) => p.setDouble(_kReadSpeed, v));
  }

  Map<String, Object> toMap() => {
        'textSize': _textSize.name,
        'palette': _palette.name,
        'ruby': _ruby,
        'readAloud': _readAloud,
        'readSpeed': _readSpeed,
      };

  void _apply(Map<String, dynamic> m) {
    _textSize = TextSizeLevel.values.firstWhere((e) => e.name == m['textSize'],
        orElse: () => TextSizeLevel.small);
    _palette = AppPalette.values.firstWhere((e) => e.name == m['palette'],
        orElse: () => AppPalette.standard);
    _ruby = m['ruby'] == true;
    _readAloud = m['readAloud'] == true;
    _readSpeed = ReadSpeed.parse(m['readSpeed']);
  }

  /// ログインしたとき：そのユーザーが保存した設定を読んで反映する。
  /// 保存したことがないユーザーは、標準の設定にする（前の人の設定を引き継がない）。
  /// ログアウトしたとき（uid が null）は、端末の表示はそのままにして、ユーザーとの結び付きだけ外す。
  Future<void> bindUser(String? uid) async {
    _uid = uid;
    _unsaved = false;
    if (uid == null) return;
    Map<String, dynamic>? saved;
    try {
      final d =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      saved = d.data()?['settings'] as Map<String, dynamic>?;
    } catch (_) {
      return; // 読めなければ、いまの表示のまま。
    }
    if (_uid != uid) return; // 読んでいる間にユーザーが変わった。
    if (saved != null) {
      _apply(saved);
    } else {
      resetForTest();
    }
    notifyListeners();
    await _save((p) async {
      await p.setString(_kText, _textSize.name);
      await p.setString(_kPalette, _palette.name);
      await p.setBool(_kRuby, _ruby);
      await p.setBool(_kRead, _readAloud);
      return p.setDouble(_kReadSpeed, _readSpeed);
    });
  }

  /// いまの設定を、ログイン中のユーザーの設定として保存する。保存できたら true。
  Future<bool> saveForUser() async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'settings': toMap()}, SetOptions(merge: true));
      _unsaved = false;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// テスト用：保存せずに、初期の状態へ戻す。
  void resetForTest() {
    _textSize = TextSizeLevel.small;
    _palette = AppPalette.standard;
    _ruby = false;
    _readAloud = false;
    _readSpeed = ReadSpeed.normal;
    _unsaved = false;
  }

  Future<void> _save(Future<bool> Function(SharedPreferences) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {}
  }
}
