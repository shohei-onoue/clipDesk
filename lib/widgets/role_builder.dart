import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../data/services.dart';
import '../domain/request_status.dart';

/// ログイン中ユーザーの役割を購読して builder に渡す。
/// 役割が未設定の場合は案内を表示する（自己申告で役割を選ばせない）。
class RoleBuilder extends StatelessWidget {
  const RoleBuilder({super.key, required this.builder, this.dark = false});

  /// ダーク背景の画面では true（文字と読み込み表示を明るい色にする）。
  final bool dark;

  final Widget Function(BuildContext, String uid, UserRole role) builder;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? AppColors.white : AppColors.ink;
    final uid = Services.uid;
    if (uid == null) {
      return Center(
          child: Text('ログインしてください', style: AppText.noto(16, color: fg)));
    }
    return StreamBuilder<UserRole?>(
      stream: Services.repo.watchRole(uid),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
              child: Text(
                  'エラー：役割を取得できませんでした（${snap.error}）。通信を確認して、もう一度開いてください',
                  textAlign: TextAlign.center,
                  style: AppText.noto(14, color: fg)));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(
                  color: dark ? AppColors.white : null));
        }
        final role = snap.data;
        if (role == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '権限がまだ設定されていません。責任者に招待メールの送信を依頼してください。',
                textAlign: TextAlign.center,
                style: AppText.noto(16, color: fg, height: 1.6),
              ),
            ),
          );
        }
        return builder(context, uid, role);
      },
    );
  }
}
