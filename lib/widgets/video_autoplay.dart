import 'package:video_player/video_player.dart';

/// 開いた直後に、音つきの再生を始める。始められたら true。
/// ブラウザ（主に iPhone の Safari）が音つきの自動再生をふさぐと、プレーヤーはエラーになって
/// 操作できなくなる。そのときは false を返すので、呼び出し側は作り直して、止めた状態で見せる
/// （再生ボタンを押すと、音つきで始まる）。
Future<bool> startWithSound(VideoPlayerController c) async {
  try {
    await c.play();
  } catch (_) {}
  // ふさがれたことは、少し遅れてプレーヤーに伝わる。
  await Future<void>.delayed(Duration.zero);
  return !c.value.hasError;
}
