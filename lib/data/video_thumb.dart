// 動画の最初の1コマを、軽いJPEG画像にする（一覧の静止画サムネイル用）。
// Webはブラウザの動画とcanvasで作る。スマホは未対応（null を返し、一覧は代替表示になる）。
export 'video_thumb_io.dart' if (dart.library.js_interop) 'video_thumb_web.dart';
