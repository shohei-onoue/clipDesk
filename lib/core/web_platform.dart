import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// iPhone・iPad のブラウザ（Safari など）で動いているか。
bool get isIOSWeb => kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// スマートフォン・タブレットのブラウザで動いているか。
///
/// このとき、利用者の操作なしで入力欄にフォーカスを当てると（autofocus）、
/// キーボードが出ないまま「入力中」になり、タップしてもキーボードが出なくなることがある。
bool get isMobileWeb =>
    kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);
