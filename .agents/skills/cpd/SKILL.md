---
name: cpd
description: clipdeskの変更をコミット・プッシュし、Web版をビルドしてFirebase Hostingへデプロイする。「コミットプッシュデプロイして」等の指示、または /cpd で使う。
---

# コミット・プッシュ・デプロイ (clipdesk)

## 手順

1. `git status --short` で変更を確認する。変更が無ければ、その旨を伝えて終了する。
2. `flutter analyze lib` を実行し、新規のエラーがあれば中止して報告する（既存の info/warning は無視してよい）。
3. 変更ファイルだけを `git add` する（`git add -A lib` など。`build/` や秘密情報は含めない）。
4. コミットする。メッセージは日本語で変更内容を端的に書き、末尾に会話のsystem-reminderで指定された Co-Authored-By 行を付ける。
5. `git push` する。
6. `flutter build web --release` でWeb版をビルドする。
7. `firebase deploy --only hosting` でデプロイする（公開先: https://clipdesk-app.web.app）。
8. コミットID・プッシュ結果・デプロイ結果を3行以内で報告する。
9. 起動（または再起動）のたびに、前回の追記以降の変更内容を `~/Desktop/work_log.md` の今日の日付の見出し（`## 日付`）の下にある小タイトル `### clipdesk` の直下へ、箇条書き1〜2行で端的に追記する（日付見出しが無ければ作る。小タイトル `### clipdesk` が無ければ日付見出しの下に作ってから追記する。既にある場合は新しく作らず、そのタイトル下の末尾へ追加する）。`git diff` で変更を確認して書く。

## 注意

- 実機アプリには反映されない（Webのみ）。必要なら `/debug5000` か `/debugwifi` を案内する。
- ブラウザには古い画面が残ることがあるため、反映されない場合はスーパーリロード（Cmd+Shift+R）を案内する。
- 回答は端的に・やさしい言葉で書く。
