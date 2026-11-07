# clipdesk デザインシステム

UI を作る・直すときの基準。値は `tokens.json`、部品の使い方は `components.md`。

## Flutter への対応

- 色は `lib/core/app_colors.dart`、文字は `lib/core/app_text.dart`、余白・角丸は `lib/core/app_tokens.dart` を使う。`Color(0x…)` や数値の直書きをしない。
- 基準の4色：`AppColors.bg`（=`surface-100`）、`AppColors.blue`（=`brand`）、`AppColors.ink`（=`ink`）、`AppColors.amber`（=`accent`）。
- `amber` は塗り専用。背景の上の文字には使わない（2.3:1）。塗りの上の文字は `ink`。
- 下の本文はトークン名で書かれている。`tokens.json` の名前と、`app_colors.dart` / `app_tokens.dart` の定数は次の対応（`surface-200` → `AppColors.surface200` のように camelCase）。
- アプリは現在ライトテーマのみ。ダークの値は `tokens.json` に参考として残す。
- 部品名（`CueRow` など）は設計上の名前。実装は `lib/widgets/` の既存ウィジェットに寄せ、足りなければ同名で追加する。

---

動画編集指示書アプリは、撮影・企画担当が編集者へ渡す「動画編集指示書」を作るためのアプリです。指示は時間軸（タイムコード）とトラック（映像・音声・テロップ・効果）で整理して見せます。

## 文体

- 指示文は「です・ます」調で、1行1指示。動詞で終える：「ここでカットしてください」「BGMをフェードアウトします」。
- 位置はタイムコード `HH:MM:SS:FF`（例：`00:01:12:05`）。区間は `00:01:12:05 – 00:01:18:00`、半角ハイフンでなくEn dashを使う。
- 用語は編集現場の語を使う：カット、テロップ、BGM、SE、ナレーション、トランジション、色調補正。英語の言い換えはしない。
- 感嘆符・絵文字は使わない。エラーは原因と次の操作を書く：「エラー：開始位置が終了位置より後です。開始を修正してください」。
- UIラベルは短い名詞または動詞：「指示を追加」「書き出し」「保存」。

## 色

- 面は `surface-100`（アプリ背景）→ `surface-200`（カード・入力）→ `surface-300`（タイムライン）。文字は `ink`、補足は `ink-muted`。
- `brand`（青 #0052CC）は操作の色：主ボタン、リンク、選択、フォーカスリング（2px実線）。主ボタンは1画面に1つ。塗りの上の文字は `on-brand`。
- `accent`（琥珀 #D97706）は「今ここ」の強調：再生ヘッド、現在位置、マーカー。塗り専用で、背景の上の文字には使わない（2.3:1）。塗りの上の文字は `on-accent`（`ink`）。
- 基準色は4つ：`surface-100`=#D6DADE、`brand`=#0052CC、`ink`=#1A1D20、`accent`=#D97706。
- トラックは種類ごとに固定色。映像=`track-video`、音声=`track-audio`、テロップ=`track-text`、効果=`track-fx`。文字は `track-*`、背景は対応する `track-*-bg`。色だけで区別せず、必ずタグに語句（映像／音声／テロップ／効果）を添える。
- 状態色：完了=`success`（青）、注意=`warn`、エラー=`danger`。成功と失敗を赤緑で分けない。必ず語句を併記する。
- ライト・ダークの2テーマ。`data-theme` で切り替える。

## 文字

- 本文は `body`、補足は `body-sm`、ボタン・タグ・ラベルは `label`。見出しは `h1`〜`h3`。
- タイムコードは必ず `timecode`（等幅）で表示し、桁を揃える。
- 和文は Noto Sans JP、タイムコードは JetBrains Mono（いずれも Google Fonts から読み込み。未読込時はシステムフォントに置換）。

## 形・余白・影

- 余白は `space-1`〜`space-8` の段のみ。指示行の内側は `space-3`、カードは `space-4`、セクション間は `space-8`。
- 区切りは枠線（`line`）で行う。入力欄・ボタンの枠は `line-strong`。影は `shadow-1` をドラッグ中・メニューにのみ使う。
- 角丸：タグ・クリップ `radius-sm`、ボタン・入力 `radius-md`、カード `radius-lg`。

## 部品

- `Button`：操作。主ボタンは1画面に1つ。
- `Tag`：トラック種別の表示。
- `Field`：ラベル・ヒント・エラー付きの入力欄（1行／複数行）。
- `CueRow`：指示書の1行（開始・終了タイムコード、トラック、指示文）。指示書はこの行を縦に並べて作る。
- チャット：`ChatHeader`、`ChatBubble`（ユーザー右・ボット左）、`TypingDots`、`SuggestCard`（横スクロールの提案）、`ChatInput`、`TabBar`。ボットとの対話で指示を固め、確定したものを `CueRow` にする。
- 設定：`ListRow`（スイッチ行／遷移行。角丸カード1枚が1項目）、`Switch`。
- メニュー：`Drawer`（左から開く。幕は `scrim`）、`DrawerTile`（上部のショートカット2つ）、`DrawerItem`（アイコン・項目名・補足・件数・シェブロン）。
- ホーム（依頼の進捗）：`AppBar`、`TopTabs`、`Select`、`Chip`、`EmptyCard`、`RequestCard`（`StatusTag` と `ProgressBar` を内包）。状態は受付・編集中・確認待ち・納品済みで、必ず語句を添える。
- アイコン：`Icon`、`IconButton`。必ず `label` を付ける。
- 画面例：`HomeScreen`、`ChatScreen`、`SettingsScreen`（部品の組み方の見本）。

## アイコン

アイコンは `Icon` に内蔵（24px・線幅1.75・単色、`currentColor`）。意味を持つ操作は語句または `label` を添える。独自のアイコンを足す場合は同じ線幅・単色で揃える。ロゴは未提供のため、名称は文字組みで表す。
