---
name: debugw
description: clipdeskをWebで2画面同時にデバッグ起動・再起動する（5001=依頼者、5002=編集者。別ウィンドウで開く）。「2つとも再起動して」「2画面でデバッグして」等の指示、または /debugw で使う。
---

# 2画面デバッグ (clipdesk)

依頼者（5001）と編集者（5002）を同時に確認するため、Webサーバーを2つ起動し、Chromeの別ウィンドウで開く。
ポートごとにFirebaseのログイン状態が分かれる。デバッグ実行では、5001は依頼者、5002は編集者のテストアカウントで自動ログインする（`lib/core/debug_auto_login.dart`。デプロイ版には入らない）。

## まず：サーバーが動いているなら、ホットリスタートで反映する（速い）

5001・5002 のサーバーが動いていれば、プロセスを止めずに、ホットリスタートの合図（SIGUSR2）を送る。数秒で、コードの変更が反映される。ログイン状態も保たれる。

```
for p in 5001 5002; do
  pid=$(pgrep -f "flutter_tools.snapshot run -d web-server --web-port $p")
  [ -n "$pid" ] && kill -USR2 $pid
done
sleep 10
tail -3 /tmp/f5001.log /tmp/f5002.log   # "Restarted application" が出れば成功
```

- 開いているブラウザのタブはそのまま使える。ウィンドウを開き直す必要はない（画面が変わらないときは Cmd+Shift+R）。
- 次のときは、下の「起動・再起動の手順」で完全に起動し直す：サーバーが動いていない／`Restarted application` が出ない／エラーが出た／pubspec.yaml や assets、Firebase設定を変えた。

## 起動・再起動の手順（完全に起動し直す）

1. 稼働中のサーバーを止める。止めたあと2秒待つ。

```
pkill -f "web-port 500"; sleep 2
```

2. **5001 → 5002 の順に、1つずつ**起動する。同時に起動すると、共有のbuildフォルダが競合して2つ目が失敗する。
   - 各サーバーは `nohup flutter run -d web-server --web-port <ポート> > /tmp/f<ポート>.log 2>&1 &` で起動する。
   - ログに `is being served` が出るまで待ってから、次の起動へ進む（最大およそ160秒）。
   - 出なければ、ログの Error / failed を確認して報告する。

```
cd <プロジェクト> && (nohup flutter run -d web-server --web-port 5001 > /tmp/f5001.log 2>&1 &)
for i in $(seq 1 80); do grep -q "is being served" /tmp/f5001.log 2>/dev/null && break; sleep 2; done
grep -E "served|Error|failed" /tmp/f5001.log
```

   5002も同じ手順。Bashのtimeoutは長め（400000ms）にする。

3. 2つとも起動したら、Chromeで**別々の新しいウィンドウ**に開く。

```
osascript <<'APPLESCRIPT'
tell application "Google Chrome"
  make new window
  set URL of active tab of front window to "http://localhost:5001"
  make new window
  set URL of active tab of front window to "http://localhost:5002"
  activate
end tell
APPLESCRIPT
```

4. 結果を短く報告する（5001=依頼者、5002=編集者のURL）。前回のウィンドウが残っていたら閉じてもらう。

## ログイン状態（必須）

5001・5002 のどちらも、デバッグ画面は**ログイン済みの状態で表示する**（毎回ログインさせない）。

- 5001 は依頼者（iraisha@example.com）、5002 は編集者（henshuusha@example.com）で、起動時に自動ログインし、メイン画面（/menu）から始まる。実装は `lib/core/debug_auto_login.dart` と `lib/main.dart` の `debugAutoLogin()`。
- ログイン状態はブラウザに保存される（`Persistence.LOCAL`）。ホットリスタートでも、`main()` が再実行されて自動ログインが保たれる。
- 開いたあと、ログイン画面が出ていないか確認する。ログイン画面が出たら、報告する前に原因を調べて直す：ブラウザのコンソールに「デバッグ自動ログインに失敗しました」が出ていないか、Firebase 側にテスト用アカウントがあるか、ポートが 5001／5002 か。
- 自動ログインは、デバッグ実行・Web・5001／5002 のときだけ動く。**デプロイ版（release）には入れない**。`debug_auto_login.dart` の認証情報はコミットしない／デプロイに含めないことを守る（`flutter build web --release` に認証情報が含まれていないか、必要なら確認する）。

## 作業ログ

起動（または再起動）のたびに、前回の追記以降の変更内容を `~/Desktop/work_log.md` の今日の日付の見出し（`## 日付`）の下にある小タイトル `### clipdesk` の直下へ、箇条書き1〜2行で端的に追記する（日付見出しが無ければ作る。小タイトルが既にあれば新しく作らず、そのタイトル下の末尾へ追加する）。`git diff` で変更を確認して書く。

## 注意

- 通常はホットリスタート（上記）で反映する。完全な再起動は、動いていないときや失敗したときだけ。
- 古い画面が残るときは、スーパーリロード（Cmd+Shift+R）を案内する。
- 回答は端的に・やさしい言葉で書く。
