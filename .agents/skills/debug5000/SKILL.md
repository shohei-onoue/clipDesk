---
name: debug5000
description: clipdeskを接続中の実機（Android/iOS）でデバッグ起動・監視・再起動する。「実機デバッグして」「実機に反映して」等の指示、または /debug5000 で使う。
---

# 実機デバッグ (clipdesk)

clipdeskを接続中の実機上でビルド・起動し、ログを監視して、コード変更後は再起動して反映する手順。

## 1. 実機の確認

```
flutter devices
```

- `macOS (desktop)` や `Chrome (web)` はデスクトップ/Web扱いであり対象外。実際のAndroid/iOS実機（例: `Android 16 (API 36)` のような物理デバイス行）を探す。
- 対象は接続中のAndroid/iOS実機。複数ある場合は、どれを使うかユーザーに確認する。
- 実機が見つからない場合は、ケーブル接続・ロック解除、またはWi-Fiデバッグ用のDeveloper Mode設定を確認するようユーザーに依頼して待つ。無理に推測で進めない。

## 2. 起動

```
flutter run -d <device_id>
```

- 必ず `run_in_background: true` で実行する（対話的に張り付いたままになるため）。
- 出力ファイルパスを控えておく。

## 3. ログ監視

Monitorツールで出力ファイルを `tail -f` し、Google Play services系のノイズ（`GoogleApiManager`, `PhFlagUpdateRegistry`, `FlagStore`, `Phenotype`）を除外した上で、以下のシグナルだけ拾うフィルタを使う。

```
tail -f -n +1 "<output-path>" \
  | grep -Ev "GoogleApiManager|PhFlagUpdateRegistry|FlagStore|Phenotype" \
  | grep -E --line-buffered "Syncing files|A Dart VM|Flutter run key commands|FAILED|Exception|Lost connection|Application finished"
```

- 起動成功の合図: `A Dart VM Service on ... is available at:` のログ。これが出たらユーザーに実機での起動完了を報告する。
- ノイズ行（フィルタ済みで除外されるGoogleApiManager等）が万一届いても、それはアプリ本体のエラーではないので無視してよい旨を伝えるだけで良い。

## 4. コード変更後の反映

Dart VM ServiceへのJSON-RPC直叩き（`reloadSources`）はFlutterのフロントエンドコンパイラを経由しないため失敗する（`Error while starting Kernel isolate task`）。また `flutter run` の対話プロセスへ標準入力でキー送信する手段がないため、**hot reloadは使わずプロセスを再起動**する。

1. 稼働中のMonitorタスクとBash（`flutter run`）タスクをそれぞれ `TaskStop` で停止する。
2. 手順2からやり直す（`flutter run -d <device_id>` を再度 `run_in_background: true` で起動）。
3. 手順3の監視を再度張る。
4. 起動完了のログを検知したらユーザーに実機への反映完了を報告する。

## 5. 作業ログの追記

起動（または再起動）のたびに、前回の追記以降の変更内容を `~/Desktop/work_log.md` の今日の日付の見出し（`## 日付`）の下にある小タイトル `### clipdesk` の直下へ、箇条書き1〜2行で端的に追記する（日付見出しが無ければ作る。小タイトル `### clipdesk` が無ければ日付見出しの下に作ってから追記する。既にある場合は新しく作らず、そのタイトル下の末尾へ追加する）。`git diff` で変更を確認して書く。

## 注意

- `flutter analyze` は既存の警告（`use_build_context_synchronously` や `deprecated_member_use` など）が残っていても、新規に増えていなければ問題なしと判断してよい。
