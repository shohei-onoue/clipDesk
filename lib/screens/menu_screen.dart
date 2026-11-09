import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import '../data/services.dart';
import '../domain/request_status.dart';
import '../domain/staff_access.dart';
import '../widgets/app_drawer.dart';
import '../widgets/role_builder.dart';

/// ログイン後のメイン画面（Figma 268:879「main_screen」）。
/// 「依頼者ページ」「編集者ページ」「依頼一覧」「利用者登録」のカードから各画面へ進む。
/// カードは付与された権限に応じて出す（依頼者／編集者／両方、責任者はスタッフ管理も）。暫定仕様（FigJamで未確定）。
/// - 依頼者ページ → /home（依頼者の立場）、編集者ページ → /home（編集者の立場）
/// - 依頼一覧 → /progress（動いている案件を全員分）
/// - 利用者登録 → /staff（責任者だけ）
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
            const _MenuAppBar(),
            Expanded(
              child: RoleBuilder(
                builder: (context, uid, role) => StreamBuilder<StaffAccess>(
                  stream: Services.repo.watchAccess(uid),
                  builder: (context, snap) {
                    final a = snap.data ?? StaffAccess.none;
                    final cards = <Widget>[
                      if (a.canRequest)
                        _MenuCard(
                          ruby: 'いらいしゃ',
                          title: '依頼者ページ',
                          image: 'assets/menu/iraisha.png',
                          imageBox: const Rect.fromLTWH(10, 5, 155, 117),
                          fit: BoxFit.cover,
                          textLeft: 10,
                          onTap: () =>
                              _go(context, UserRole.requester, '/home'),
                        ),
                      if (a.canEdit)
                        _MenuCard(
                          ruby: 'へんしゅうしゃ',
                          title: '編集者ページ',
                          image: 'assets/menu/henshusha.png',
                          imageBox:
                              const Rect.fromLTWH(10.29, 8, 145.499, 113.929),
                          fit: BoxFit.fill,
                          textLeft: 10,
                          onTap: () => _go(context, UserRole.editor, '/home'),
                        ),
                      _MenuCard(
                        ruby: 'いらいいちらん',
                        title: '依頼一覧',
                        image: 'assets/menu/ichiran.png',
                        imageBox: const Rect.fromLTWH(8, -4, 144, 120),
                        fit: BoxFit.cover,
                        textLeft: 33,
                        onTap: () => _go(context, null, '/progress'),
                      ),
                      if (a.manager)
                        _MenuCard(
                          ruby: 'りようしゃとうろく',
                          title: '利用者登録',
                          image: 'assets/menu/staff.png',
                          imageBox: const Rect.fromLTWH(13, 0, 147, 125),
                          fit: BoxFit.cover,
                          textLeft: 19,
                          onTap: () => _go(context, null, '/staff'),
                        ),
                    ];
                    return SingleChildScrollView(
                      child: Padding(
                        // アプリバーとの間 95、カード群の上下 35（Figma の余白）。
                        padding: EdgeInsets.only(
                            top: r.y(95 + 35), bottom: r.y(35 + 24)),
                        child: Center(
                          child: Column(
                            children: [
                              for (var i = 0; i < cards.length; i++) ...[
                                if (i > 0) SizedBox(height: r.y(40)),
                                cards[i],
                              ],
                            ],
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

/// アプリバー：高さ65、戻る（24）・タイトル（24）・メニュー（40）。
class _MenuAppBar extends StatelessWidget {
  const _MenuAppBar();

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      height: r.y(65),
      color: AppColors.ink,
      child: Stack(
        children: [
          // 戻る：アイコン24を x=13 に置く（タップ領域は48）。
          Positioned(
            left: r.x(13 - 12),
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                tooltip: '戻る',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(Icons.arrow_back_ios_new,
                    size: r.x(24), color: AppColors.surface200),
              ),
            ),
          ),
          Positioned(
            left: r.x(45),
            top: 0,
            bottom: 0,
            child: Center(
              child: Text('Menu',
                  style: AppText.noto(r.x(24),
                      weight: FontWeight.w400, color: AppColors.surface200)),
            ),
          ),
          // メニュー：アイコン40を x=339 に置く。
          Positioned(
            left: r.x(339 - 4),
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                tooltip: 'メニューを開く',
                onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
                icon: Icon(Icons.menu,
                    size: r.x(40), color: AppColors.surface200),
              ),
            ),
          ),
        ],
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
  });

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
                  top: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ruby,
                          style: AppText.noto(r.x(14),
                              weight: FontWeight.w400,
                              color: AppColors.surface200)),
                      Text(title,
                          style: AppText.noto(r.x(24),
                              weight: FontWeight.w400,
                              color: AppColors.surface200)),
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
