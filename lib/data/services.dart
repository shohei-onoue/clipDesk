import 'package:firebase_auth/firebase_auth.dart';

import 'request_repository.dart';

/// 画面から使う共有の保存層。テストでは [repo] を差し替える。
class Services {
  Services._();

  static RequestRepository? _repo;
  static RequestRepository get repo => _repo ??= RequestRepository();
  static set repo(RequestRepository v) => _repo = v;

  /// テスト用：ログイン中のユーザーIDを差し替える（Firebase なしで画面を開くため）。
  static String? uidOverride;

  static String? get uid =>
      uidOverride ?? FirebaseAuth.instance.currentUser?.uid;
}
