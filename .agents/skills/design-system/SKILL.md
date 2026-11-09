---
name: design-system
description: clipdeskのデザインシステム（docs/design-system）に合わせてUIを作る・直す。「デザインシステムに合わせて」「画面を作って／直して」等の指示、または /design-system で使う。色や余白だけでなく、部品と画面の組み方まで合わせる。
---

# デザインシステム適用 (clipdesk)

UIを作る・直すときの手順と規則。詳細は `docs/design-system/` が正で、このスキルは要点だけを持つ（値は写さない）。

## 最初に読むもの（着手前に必ず）

1. `docs/design-system/README.md`：文体・色・文字・形・部品の一覧
2. `docs/design-system/components.md`：部品ごとの役割、渡すもの、画面例（HomeScreen など）
3. `docs/design-system/tokens.json`：値（色・余白・角丸・文字サイズ）。値が必要なときだけ見る

## 手順

1. 対象の画面に当たる「画面例」（`components.md`）があれば、その並び順・部品・余白を先に書き出す。
2. 今の実装と見比べ、**部品の構成と並び順**から合わせる（色や余白は最後）。
3. 部品は `lib/widgets/` の既存ウィジェットに寄せる。足りなければ部品名どおりに追加する。
4. 色・余白・角丸・文字は定数だけを使う（下の対応表）。
5. `flutter analyze lib` と `flutter test` を通す。
6. 下の確認項目で照合してから報告する。報告には「合わせた点」と「合わせられなかった点」を分けて書く。
7. 画面の構成が変わるときは、確定前に変更案を見せる。コミット・デプロイは `/cpd` まで行わない。

## Flutterの定数

| 種類 | 置き場所 | 例 |
|---|---|---|
| 色 | `lib/core/app_colors.dart` | `bg`(=surface-100)、`surface200`、`blue`(=brand)、`ink`、`inkMuted`、`amber`(=accent)、`warn`、`danger`、`line`、`lineStrong` |
| 文字 | `lib/core/app_text.dart` | `h1`〜`h3`、`body`、`bodySm`、`label` |
| 余白・角丸 | `lib/core/app_tokens.dart` | `AppSpace.s1`〜、`AppRadius.sm/md/lg` |

`Color(0x…)` や数値の直書きはしない。

## 規則の要点

- **文体**：「です・ます」調。感嘆符・絵文字なし。エラーは「エラー：原因。次の操作」の形。ラベルは短い名詞か動詞。
- **面**：背景 `surface-100` → カード・入力 `surface-200` → `surface-300`。文字は `ink`、補足は `ink-muted`。
- **brand（青）**：操作の色（主ボタン、リンク、選択、フォーカス）。主ボタンは1画面に1つ。
- **accent（琥珀）**：塗り専用。背景の上の文字には使わない。塗りの上の文字は `ink`。注意の文字は `warn`。
- **状態**：色だけで示さず、必ず語句を添える。成功と失敗を赤緑だけで分けない。
- **余白**：`space` の段のみ。カードの内側は `space-4`、セクション間は `space-6`〜`space-8`、左右は `space-4`。
- **区切り**：枠線（`line`）。入力・ボタンの枠は `line-strong`。影は、ドラッグ中とメニューだけ。
- **角丸**：タグ `sm`、ボタン・入力 `md`、カード `lg`。
- **アイコン**：意味のある操作には語句か `label` を付ける。タップ領域は40px以上。

## 部品の早見（詳細は components.md）

| 部品 | 要点 |
|---|---|
| AppBar | brand 塗り、タイトル中央、アイコンに label |
| Chip | 選択＝brand の2px枠＋brand 文字、未選択＝line-strong の細枠、間隔 space-2 で折り返し |
| TopTabs | 2〜3項目、選択＝brand 文字＋4px下線 |
| RequestCard | 2列グリッド（gap space-3）、StatusTag は語句つき、ProgressBar と数値、タイトルは2行まで |
| TabBar | 5項目まで、現在地は塗りアイコン＋太字、中央の主操作は brand の丸（画面に1つ） |
| Select | 高さ48、先頭は「すべての〜」 |
| ListRow | カード1枚が1項目、高さ56以上、間隔 space-2 |
| Drawer | 幅は画面の約9割（最大360）、未読は accent 塗りの badge、0件は出さない |

## 画面例：HomeScreen（並び順）

AppBar（メニュー・タイトル・更新）→ TopTabs（進行中／完了）→「期限が近い依頼」（空なら EmptyCard）→「絞り込み」（Select と Chip）→ RequestCard の2列グリッド → TabBar（中央に「新しい依頼」）。見出しは `h3`、背景 `surface-100`、カード `surface-200`。

## 確認項目（報告前に照合）

- [ ] 色・余白・角丸・文字に直書きがない（`grep -n "Color(0x" lib/screens lib/widgets`）
- [ ] 画面の並び順・部品が、画面例／部品の説明と一致している
- [ ] 状態表示に語句が添えてある
- [ ] amber を文字色に使っていない
- [ ] 主ボタンが1画面に1つ
- [ ] 文言が「です・ます」調で、感嘆符・絵文字がない
- [ ] `flutter analyze lib` と `flutter test` が通る

## 注意

- 作業の前提は `docs/video-editing-flow.md`（フローに関わる場合）。資料の未確定事項を確定仕様として実装しない。
- デザイン資料と実装がずれたら、ユーザーの最新指示を優先し、資料側の更新も提案する。
- 回答は端的に・やさしい言葉で書く。
