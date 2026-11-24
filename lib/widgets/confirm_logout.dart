import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/app_tokens.dart';
import 'ruby_text.dart';

/// ログアウトの確認ポップアップ。「ログアウト」を選んだときだけログアウトし、最初の画面へ戻る。
/// やめる場合は何も起きない。
Future<void> confirmAndLogout(BuildContext context) async {
  final radius = BorderRadius.circular(AppRadius.md);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.white.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text('ログアウトしますか？', style: AppText.dark(18)),
      content: Text('ログアウトすると、ログイン画面に戻ります。',
          style: AppText.dark(14, weight: FontWeight.w400, height: 1.5)),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.white,
            side: BorderSide(color: AppColors.white.withValues(alpha: 0.55)),
            minimumSize: const Size(96, 44),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.blue,
            foregroundColor: AppColors.on(AppColors.blue),
            minimumSize: const Size(96, 44),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          child: const Text('ログアウト'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await FirebaseAuth.instance.signOut();
  if (context.mounted) {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }
}
