import 'package:web/web.dart' as web;

/// [timeStamp] はブラウザの操作の時刻（ページを開いてからの時間）。
/// 負や1秒を超える値は、時刻の基準が合わないとみなして、遅れなしにする。
Duration eventAge(Duration timeStamp) {
  final now =
      Duration(microseconds: (web.window.performance.now() * 1000).round());
  final age = now - timeStamp;
  if (age.isNegative || age > const Duration(seconds: 1)) return Duration.zero;
  return age;
}
