import 'package:flutter/material.dart';

import '../core/app_text.dart';
import '../data/services.dart';
import '../domain/request_status.dart';

/// ログイン中ユーザーの役割を購読して builder に渡す。
/// 役割が未設定の場合は案内を表示する（自己申告で役割を選ばせない）。
class RoleBuilder extends StatelessWidget {
  const RoleBuilder({super.key, required this.builder});

  final Widget Function(BuildContext, String uid, UserRole role) builder;

  @override
  Widget build(BuildContext context) {
    final uid = Services.uid;
    if (uid == null) {
      return const Center(child: Text('ログインしてください'));
    }
    return StreamBuilder<UserRole?>(
      stream: Services.repo.watchRole(uid),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('役割の取得に失敗しました：${snap.error}'));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final role = snap.data;
        if (role == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '権限がまだ設定されていません。責任者に招待メールの送信を依頼してください。',
                textAlign: TextAlign.center,
                style: AppText.noto(16, height: 1.6),
              ),
            ),
          );
        }
        return builder(context, uid, role);
      },
    );
  }
}
