# clipdesk 作業時の参照

動画編集依頼の業務フロー、画面構成・画面遷移、権限、進捗、通知、動画の提出・承認・修正に関係する作業では、着手前に `docs/video-editing-flow.md` を読むこと。
無関係な作業では読み込み不要。

同資料はFigJamの確認時点の記録。未確定事項を確定仕様として実装しない。ユーザーの最新指示を優先し、フロー変更時には資料も更新する。

## デザインシステム

UI の作成・変更では、着手前に `docs/design-system/README.md` を読むこと。値は `docs/design-system/tokens.json`、部品の使い方は `docs/design-system/components.md`。

- 色・余白・角丸は `lib/core/app_colors.dart` と `lib/core/app_tokens.dart` の定数だけを使い、直書きしない。
- 文言は「です・ます」調。状態は色だけでなく語句も添える。

## Figma デザイン参照先

- UIデザイン（Figma Design）：https://www.figma.com/design/7N2NVYYwavvSpAr7LISjvT/VideoEditingInstructions?node-id=185-215&m=dev
  - ファイルキー：`7N2NVYYwavvSpAr7LISjvT`
  - 基準ノードID：`185:215`
- 業務フロー・画面遷移（FigJam）：https://www.figma.com/board/4yJfDm2Jr66DJXoq30ibay/VideoEditingInstructions?node-id=0-1
  - ファイルキー：`4yJfDm2Jr66DJXoq30ibay`
