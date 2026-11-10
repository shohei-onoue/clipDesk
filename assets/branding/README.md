# Clip Desk アプリアイコン

元画像：`assets/menu/henshusha.png`。内蔵imagegenで、元キャラクターを参照して制作しました。
マスター：`app-icon.png`（1024×1024、不透明）。元画像は変更していません。

顔・ヘッドホン・パーカーを主役にし、文字、パソコン、キーボード、周辺機器を省いた構成です。背景は黒〜青、キャラクター固有の茶・ピンク・紫はイラストの色として保持しています。UIの基準色4色の制約はキャラクターの素材色には適用しません。

## 配信先

- Web：manifestの192/512px、maskableの192/512px
- iPhoneのホーム画面追加：Apple touch icon 180px
- ブラウザ：favicon 32px
- Android：既存ic_launcherの5密度
- iOS：AppIcon.appiconsetの全サイズ

サイズの再出力はリポジトリ直下で`python3 scripts/generate_app_icons.py`（macOSのsipsを使用）。画像のデザインは変更せず、サイズだけ変換します。Webは新しいファイル名を参照して旧アイコンのキャッシュと区別しています。

Webは次回のビルド・デプロイ、ネイティブは次回のビルド・インストールで反映されます。すでにホーム画面に追加したアイコンはOS側に残る場合があり、その場合は追加し直します。実端末・各ランチャーのマスクでの見え方は未検証です。

## 制作プロンプト（内蔵imagegen）

Create a final production square 1024x1024 mobile app icon for Clip Desk using the attached henshusha.png mascot. Preserve the recognizable cute brown mouse identity, round pink ears, black friendly eyes, tiny smile, dark blue over-ear headphones and purple hoodie. Simplify to a large centered head-and-shoulders portrait, front-facing, effortlessly cool and cute. Remove computer, keyboard, mouse peripheral, cables, external drive and tail from the composition. NO text, NO letters, NO logos, NO symbols, NO extra objects, NO sparkles, NO frames, NO inset rounded-square border. Extremely clean readable silhouette at 32px, refined smooth thick dark outlines with a subtle cream outer separation, polished original cartoon illustration matching reference. Full-bleed opaque square background, understated smooth charcoal #1A1D20 to deep blue #0052CC gradient. Mascot's entire important head/ears/headphones silhouette must stay within centered circle radius 38% of canvas for maskable safe area; ample quiet background around subject, hoodie extends below head but remains inside central 76% of image. Center portrait visually balanced. Background goes all the way to square corners, no pre-rounded corners. Restrained minimal composition, stylish yet adorable.
