# 部品の使い方

各部品の役割と、呼び出し側が渡すもの。Props 名は Flutter ではコンストラクタ引数に読み替える。

## AppBar

画面最上部のバー。`brand` 塗りに `on-brand` の文字とアイコン。

- 呼び出し側が渡すもの：`title`、`left`（メニュー等の `IconButton`）、`right`（更新等）。
- タイトルは中央、短い名詞（例：「依頼」）。アイコンボタンには必ず `label` を付ける。

## Button

指示書アプリのすべての操作に使うボタン。

- 1画面に `variant="primary"` は1つだけ（例：「書き出し」）。保存・追加などは `secondary`、補助操作は `ghost`、削除は `danger`。
- 呼び出し側が渡すもの：`children`（短い動詞または名詞、語句のみ）、`onClick`。
- `danger` は色だけに頼らず、ラベルに「削除」など語句を入れる。
- 無効時は `disabled`。理由が必要ならボタンの近くに `body-sm` で書く。
- 良い例：「指示を追加」。悪い例：「ここをクリック」、感嘆符、絵文字。

## ChatBubble

チャットの吹き出し。`from="user"` は右寄せ（白地＋枠線）、`from="bot"` は左寄せ（`bubble-bot` の青みの地）。

- 呼び出し側が渡すもの：`children`（本文）、`time`（例 `20:31`、吹き出しの外側下に表示）。ボットの返答には `feedback`（`IconButton` の「役に立った／役に立たなかった」）を渡せる。
- 応答待ちは `TypingDots` を左寄せで置く。
- ボットの文体は「です・ます」調で、タイムコードや用語は聞き返して確定する（例：「どのあたりに入れますか？タイムコードで教えてください」）。
- 最大幅は親の幅から56pxを引いた値。長い文は折り返す。

## ChatInput

画面下部のメッセージ入力バー。1行入力と送信ボタン（`IconButton`）。

- 呼び出し側が渡すもの：`value` と `onChange`（または `defaultValue`）、`onSend`、任意で `placeholder`。
- 入力欄は枠（`line-strong`）で囲み、プレースホルダーは `ink-muted`。ラベルは `aria-label` で付ける。
- 上にタブバー、その上にメッセージ列を置く。キーボード表示時は入力バーを持ち上げる。

## ChatScreen

対話式ボットで指示書を作る画面の組み方（画面例）。

- 上から `ChatHeader`（左：新規、中央：タイトル、右：情報）、メッセージ列、`SuggestCard` の横スクロール列、`ChatInput`、`TabBar`。
- 日付は中央寄せの小さなチップ（`surface-300`、`body-sm`）で区切る。
- ボットは質問を1つずつ返し、指示が固まったら `SuggestCard` で「指示書に追加」の候補を見せる。確定した指示は `CueRow` として指示書画面に並ぶ。
- ユーザーの発話は右、ボットは左。時刻は吹き出しの外側に置く。

## Chip

絞り込み用の丸いチップ（例：すべて／受付／編集中／確認待ち／納品済み）。

- 呼び出し側が渡すもの：`selected`、`onClick`、`children`（短い語句）。
- 選択中は `brand` の2px枠と `brand` の文字。未選択は `line-strong` の細い枠。`aria-pressed` で状態を伝える。
- 折り返して並べる（`flex-wrap`、間隔 `space-2`）。単一選択が基本。

## CueRow

指示書の1行。開始・終了タイムコード、トラックのタグ、指示文を横に並べる。

- 呼び出し側が渡すもの：`start`・`end`（`HH:MM:SS:FF`）、`track`、`children`（指示文、1文1指示）、任意で `note`。
- 時間順に縦へ並べる。編集中の行だけ `selected`。
- 区間は `end` の前にEn dashが自動で付く。`start` より前の `end` は渡さず、`Field` の `error` で知らせる。
- 良い例：「BGMをフェードアウトします」。悪い例：1行に複数の指示を詰め込む。

## Drawer

左から開くメニュー用のパネル。画面の約9割の幅（最大360px）で、右端に背面の画面が `scrim` 越しに見える。

- 構成は上から、ショートカット2つ（`DrawerTile`：アイコン＋語句、正方形に近い角丸）、区切り線付きのメニュー列（`DrawerItem`）、最下部のバージョン表示（`footer`）。
- `DrawerItem` は左にアイコン、中央に太字の項目名と1〜2行の補足（`ink-muted`）、右にシェブロン。未読件数は項目名の横に `badge`（`accent` 塗り・`ink` 文字）で出す。0件なら出さない。
- 呼び出し側が渡すもの：`open`、`title`（読み上げ名）、`onClose`、`tiles`、`children`、`footer`。幕のタップで閉じる。
- `role="dialog"`・`aria-modal`。開いたら先頭の要素へフォーカスし、閉じたら開いた要素へ戻す。
- 設定のスイッチ行など細かい設定は `Drawer` に入れず、遷移先の設定画面（`SettingsScreen`）に置く。
- プレビュー用の `contained` は実画面では付けない。

## Field

ラベル・ヒント・エラー付きの入力欄。1行入力と複数行（`multiline`）に対応。

- 呼び出し側が渡すもの：一意の `id`、`label`、値（`value` と `onChange`、または `defaultValue`）。
- タイムコード欄は `mono` を付け、`placeholder="00:00:00:00"` とヒントに形式を書く。
- エラーは `error` に原因と次の操作を書く。表示は「エラー：」が自動で付く。
- ラベルは常に表示する。プレースホルダーをラベルの代わりにしない。

## HomeScreen

依頼の進捗を一覧するホーム画面の組み方（画面例）。

- 上から `AppBar`（メニュー・タイトル・更新）、`TopTabs`（進行中／完了）、「期限が近い依頼」（空のときは `EmptyCard`）、「絞り込み」（`Select` と `Chip`）、`RequestCard` の2列グリッド、`TabBar`（中央に「新しい依頼」の主操作）。
- 見出しは `h3`、セクション間は `space-6`、左右余白は `space-4`。背景は `surface-100`、カードは `surface-200`。
- 下部の `TabBar` は5項目＋中央の主操作。中央は `brand` 塗りの丸で、画面に1つだけ。
- 依頼を開くと、チャットで指示を作る画面（`ChatScreen`）へ進む。

## Icon

線画アイコン（24px・線幅1.75・単色）と、アイコンだけのボタン `IconButton`。

- `Icon` は `name`（home / chat / book / calendar / chart / edit / info / thumbUp / thumbDown / star / smile / send / chevronRight / chevronLeft / close）。色は親の `color` を継承する。
- `IconButton` は必ず `label`（読み上げ名）を渡す。押下状態を持つ場合は `selected` を渡す（評価ボタン、保存の星）。タップ領域は40px。
- 意味を持つ操作は、アイコンだけにせず近くに語句を置くか、`label` を必ず付ける。

## ListRow

設定やメニューの1行。角丸のカード1枚が1項目。

- スイッチ行：`checked` と `onChange` を渡す（例：「振動」）。
- 遷移行：`onClick` を渡すと右にシェブロンが付く。現在値があれば `value` に渡す（例：「書き出し形式　MP4」）。
- 項目名は `h3` 相当の太字で、名詞または短い動詞句。行は縦に `space-2` の間隔で並べる。
- 行全体がタップ領域（高さ56px以上）。

## RequestCard

編集依頼1件のカード。ホームの2列グリッドに並べて進捗を見せる。

- 呼び出し側が渡すもの：`title`、`status`（`received` 受付／`editing` 編集中／`review` 確認待ち／`done` 納品済み）、`thumb`（動画の静止画）、`assignee`（担当）、`progress`（0〜100）、`due`（`YYYY/MM/DD`）、`saved` と `onSave`（お気に入りの星）。
- 状態は色だけでなく語句で示す（`StatusTag`）。進捗は `ProgressBar` と数値。
- 2列グリッドは `display:grid; grid-template-columns:1fr 1fr; gap: var(--space-3)`。タイトルは2行まで。

## Select

プルダウン選択（案件・クライアントの絞り込みなど）。端末標準の選択UIを使う。

- 呼び出し側が渡すもの：`id`、`options`（文字列の配列）、`value` と `onChange`（または `defaultValue`）、任意で `label`。
- 先頭の選択肢は「すべての〜」にする。高さ48px、枠は `line-strong`。

## SettingsScreen

設定画面の組み方（部品ではなく画面例）。

- 上部に戻る矢印（`IconButton` の `chevronLeft`）、その下に `ListRow` を縦に並べる。背景は `surface-100`、左右余白は `space-4`、行間は `space-2`。
- 切り替え系（スイッチ）を先頭に、遷移系を後ろにまとめる。サポート系（よくある質問、お問い合わせ）は末尾。
- 同じ並びをドロワー（`Drawer`）に入れて、チャット画面から開くこともできる。

## SuggestCard

ボットが提案する指示のカード。横スクロールの列で並べ、「指示書に追加」の候補として見せる。

- 呼び出し側が渡すもの：`title`（短い指示名）、任意で `track`（種別タグ）、`meta`（尺・位置）、`children`（1行の説明）、`saved` と `onSave`（星で保存）。
- 幅は164px固定。列は `overflow-x:auto` の親に `gap: var(--space-3)` で並べ、右端のカードを少し見切れさせてスクロールできると伝える。
- 星は色だけで状態を示さず、塗りの有無と `aria-pressed` で示す。

## Switch

オン・オフを切り替えるスイッチ。

- 呼び出し側が渡すもの：`checked`、`onChange(next)`、`label`（何の設定か。必須）。
- オンは `brand` 塗り、オフは `surface-300`。どちらも枠（`line-strong`）で区切り、つまみの位置でも状態が分かる。
- 単独では使わず、通常は `ListRow` の中に置く。

## TabBar

画面下部の5項目ナビゲーション（ホーム・チャット・資料・カレンダー・レポートなど）。

- 呼び出し側が渡すもの：`items`（`id`・`label`・`icon`）、`active`、`onSelect`。
- 現在地は塗りアイコン＋太字＋`ink` で示す（色だけに頼らない）。他は `ink-muted`。
- ラベルは短い名詞（4文字前後）。項目は5つまで。

## Tag

トラック種別（映像・音声・テロップ・効果）を示すタグ。

- `track` を渡すと語句と色が自動で決まる。色だけで区別せず、語句は必ず表示する。
- トラック以外のラベルには `track` を省略し、`children` を渡す（中立色）。
- 1行の指示につきタグは1つ。複数トラックにまたがる指示は行を分ける。

## TopTabs

画面上部の2〜3項目の切り替えタブ（例：「進行中」「完了」）。

- 呼び出し側が渡すもの：`items`（`id`・`label`）、`active`、`onSelect`。
- 選択中は `brand` の文字と4pxの下線。他は `ink-muted`。`role="tablist"` / `tab`。
- 項目数は3つまで。ラベルは4文字前後。
