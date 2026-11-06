---
name: debugwifi
description: clipdeskをWi-Fi接続中の実機（Android）でデバッグ起動・監視・再起動する。「Wi-Fiでデバッグして」等の指示、または /debugwifi で使う。
---

# Wi-Fiデバッグ (clipdesk)

clipdeskをWi-Fi（ワイヤレスデバッグ）で接続中の実機上でビルド・起動し、ログを監視して、コード変更後は再起動して反映する手順。ケーブル接続の場合は `/debug5000` を使う。

## 1. 実機の確認

```
flutter devices
```

- 対象は同じWi-FiにつながったAndroid実機。複数ある場合は、どれを使うかユーザーに確認する。
- Wi-Fi接続の行（device idが `192.168.x.x:ポート` 形式、または `adb-...._adb-tls-connect._tcp` 形式）を対象にする。ケーブル接続の行は対象外。
- Wi-Fi接続の行が見つからない場合は、タブレットとMacが同じWi-Fiにいること、開発者向けオプションの「ワイヤレスデバッグ」がオンであることをユーザーに確認して待つ。無理に推測で進めない。
- IPアドレス・ポートは接続し直すと変わることがあるため、毎回 `flutter devices` の出力から読み取る。

## 2. 起動

```
flutter run -d <wifi_device_id>
```

- 必ず `run_in_background: true` で実行する。
- 出力ファイルパスを控えておく。

## 3. ログ監視

Monitorツールで出力ファイルを `tail -f` し、Google Play services系のノイズ（`GoogleApiManager`, `PhFlagUpdateRegistry`, `FlagStore`, `Phenotype`）を除外した上で、以下のシグナルだけ拾う。

```
tail -f -n +1 "<output-path>" \
  | grep -Ev "GoogleApiManager|PhFlagUpdateRegistry|FlagStore|Phenotype" \
  | grep -E --line-buffered "Syncing files|A Dart VM|Flutter run key commands|FAILED|Exception|Lost connection|Application finished"
```

- 起動成功の合図: `A Dart VM Service on ... is available at:`。出たらユーザーに起動完了を報告する。
- `Lost connection to device.` が出たらWi-Fi切断の可能性が高い。接続を確認するようユーザーに伝える。

## 4. コード変更後の反映

hot reloadは使わずプロセスを再起動する。

1. 稼働中のMonitorタスクとBash（`flutter run`）タスクをそれぞれ `TaskStop` で停止する。
2. 手順2からやり直す。
3. 手順3の監視を再度張る。
4. 起動完了のログを検知したらユーザーに反映完了を報告する。

## 5. 作業ログの追記

起動（または再起動）のたびに、前回の追記以降の変更内容を `~/Desktop/work_log.md` の今日の日付の見出し（`## 日付`）の下にある小タイトル `### clipdesk` の直下へ、箇条書き1〜2行で端的に追記する（日付見出しが無ければ作る。小タイトル `### clipdesk` が無ければ日付見出しの下に作ってから追記する。既にある場合は新しく作らず、そのタイトル下の末尾へ追加する）。`git diff` で変更を確認して書く。

## 注意

- `flutter analyze` は既存の警告が残っていても、新規に増えていなければ問題なしと判断してよい。
