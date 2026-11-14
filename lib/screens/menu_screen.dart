import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/request_status.dart';
import '../domain/staff_access.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/notification_bell.dart';
import '../widgets/role_builder.dart';
import '../widgets/app_icon.dart';

/// ログイン後のメイン画面（Figma 268:879「main_screen」）。
/// 「依頼する」「ダッシュボード」「ライブラリ」「登録スタッフ」のカードから各画面へ進む。
/// カードは付与された権限に応じて出す（依頼者／編集者／両方、責任者はスタッフ管理も）。暫定仕様（FigJamで未確定）。
/// - 依頼する → /chat（チャットで指示書を作る）
/// - ダッシュボード → /home（依頼者は自分の依頼、編集者は編集依頼を並べる。タイトルは共通）
/// - ライブラリ → /library（承認された編集完了動画の一覧）
/// - 登録スタッフ → /staff（責任者だけ）
/// 選んだ立場は [RequestRepository.staffMode] に保持し、roles/{uid} が 'staff' のとき使う。
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  void _go(BuildContext context, UserRole? mode, String route) {
    if (mode != null) Services.repo.staffMode = mode;
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      // Figma：背景・アプリバーとも #1A1D20（AppColors.ink）。
      backgroundColor: AppColors.ink,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'ホーム',
              leadingIcon: AppIcons.logout,
              leadingTooltip: 'ログアウト',
              onLeading: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/', (_) => false);
                }
              },
            ),
            // 未読の通知があるときだけ、アプリバーの下に通知アイコンを出す。
            const NotificationBell(),
            Expanded(
              child: RoleBuilder(
                dark: true,
                builder: (context, uid, role) => StreamBuilder<StaffAccess>(
                  stream: Services.repo.watchAccess(uid),
                  builder: (context, snap) {
                    final a = snap.data ?? StaffAccess.none;
                    final cards = <Widget>[
                      if (a.canRequest)
                        _MenuCard(
                          ruby: '',
                          title: '依頼する',
                          // ルビは「依頼」の真上だけに付ける。
                          parts: const [('依頼', 'いらい'), ('する', null)],
                          image: 'assets/menu/iraisha.png',
                          imageBox: const Rect.fromLTWH(10, 5, 155, 117),
                          fit: BoxFit.cover,
                          textLeft: 10,
                          // チャットで指示書を作る。
                          onTap: () =>
                              _go(context, UserRole.requester, '/chat'),
                        ),
                      if (a.canRequest || a.canEdit)
                        _MenuCard(
                          ruby: '',
                          title: 'ダッシュボード',
                          image: 'assets/menu/henshusha.png',
                          imageBox:
                              const Rect.fromLTWH(10.29, 8, 145.499, 113.929),
                          fit: BoxFit.fill,
                          textLeft: 10,
                          // 編集者権限があれば編集者の立場、なければ依頼者の立場で開く。
                          onTap: () => _go(
                              context,
                              a.canEdit ? UserRole.editor : UserRole.requester,
                              '/home'),
                        ),
                      _MenuCard(
                        ruby: '',
                        title: 'ライブラリ',
                        image: 'assets/menu/ichiran.png',
                        imageBox: const Rect.fromLTWH(8, -4, 144, 120),
                        fit: BoxFit.cover,
                        textLeft: 10,
                        onTap: () => _go(context, null, '/library'),
                      ),
                      if (a.manager)
                        _MenuCard(
                          ruby: '',
                          title: '登録スタッフ',
                          // ルビは「登録」の真上だけに付ける。
                          parts: const [('登録', 'とうろく'), ('スタッフ', null)],
                          image: 'assets/menu/staff.png',
                          imageBox: const Rect.fromLTWH(13, 0, 147, 125),
                          fit: BoxFit.cover,
                          textLeft: 10,
                          onTap: () => _go(context, null, '/staff'),
                        ),
                    ];
                    // アプリバーより下の領域の中央に置く。収まらない画面ではスクロールする。
                    return LayoutBuilder(
                      builder: (context, box) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: box.maxHeight),
                          child: Center(
                            child: Padding(
                              // カード群の上下 35（Figma の余白）。
                              padding: EdgeInsets.symmetric(vertical: r.y(35)),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0; i < cards.length; i++) ...[
                                    if (i > 0) SizedBox(height: r.y(40)),
                                    cards[i],
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// メニューのカード（330×104、角丸15）。ink から brand へ流れるグラデーションの上に、
/// キャラクターの画像（左）とふりがな付きの項目名（右）を置く。
class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.ruby,
    required this.title,
    required this.image,
    required this.imageBox,
    required this.fit,
    required this.textLeft,
    required this.onTap,
    this.parts,
  });

  /// 文字ごとにルビを付けたいときの分割（本文, ルビ）。ルビが null の部分は付けない。
  final List<(String, String?)>? parts;

  final String ruby;
  final String title;
  final String image;

  /// カード左上を原点にした画像の位置と大きさ。
  final Rect imageBox;
  final BoxFit fit;

  /// 文字の左端：カード幅の中央から右へ何pxか。
  final double textLeft;
  final VoidCallback onTap;

  // 161.887°のグラデーション（ink 60.6% → brand 90.1%）を、330×104 の箱の対角に換算した向き。
  static const _gradient = LinearGradient(
    begin: Alignment(-0.189, -1.838),
    end: Alignment(0.189, 1.838),
    colors: [AppColors.ink, AppColors.ink, AppColors.blue, AppColors.blue],
    stops: [0, 0.60629, 0.90123, 1],
  );

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final w = r.x(330);
    final h = r.x(104);
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: w,
          height: h,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: _gradient,
            borderRadius: BorderRadius.circular(r.x(15)),
          ),
          child: ExcludeSemantics(
            child: Stack(
              children: [
                Positioned(
                  left: r.x(imageBox.left),
                  top: r.x(imageBox.top),
                  width: r.x(imageBox.width),
                  height: r.x(imageBox.height),
                  child: Image.asset(image, fit: fit),
                ),
                Positioned(
                  left: w / 2 + r.x(textLeft),
                  right: r.x(8),
                  top: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (parts == null) ...[
                        if (ruby.isNotEmpty)
                          Text(ruby,
                              style: AppText.noto(r.x(14),
                                  weight: FontWeight.w400,
                                  color: AppColors.white)),
                        // 長い題名（編集者ダッシュボード）は、枠に収まるよう縮める。
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(title,
                              style: AppText.noto(r.x(24),
                                  weight: FontWeight.w400,
                                  color: AppColors.white)),
                        ),
                      ] else
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final (text, rb) in parts!)
                                Column(
                                  children: [
                                    // ルビの無い部分も同じ高さの空きを取り、文字の高さをそろえる。
                                    Text(rb ?? ' ',
                                        style: AppText.noto(r.x(14),
                                            weight: FontWeight.w400,
                                            color: AppColors.white)),
                                    Text(text,
                                        style: AppText.noto(r.x(24),
                                            weight: FontWeight.w400,
                                            color: AppColors.white)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
