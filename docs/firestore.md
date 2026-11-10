# Firestore の構成と運用

プロジェクト：`video-editing-instructions`（データベース `(default)`、Firestore Native）。
ルールは `firestore.rules`、インデックスは `firestore.indexes.json`。反映は `firebase deploy --only firestore`（ルールとインデックス）。

## コレクション

| パス | 役割 | 主な項目 | 読み取り | 書き込み |
|---|---|---|---|---|
| `roles/{uid}` | 権限 | `role`（`requester`／`editor`／`staff`=両方）、`manager`（管理者権限） | 本人、管理者 | 管理者（自分以外）。招待された本人が登録時に1度だけ |
| `invites/{メール小文字}` | 招待 | `role`、`manager`、`invitedBy`、`createdAt` | 管理者、招待された本人 | 管理者。本人は登録時に削除 |
| `users/{uid}` | 登録情報 | `name`、`email`、`updatedAt`、`notificationsSeenAt` | 本人、管理者 | 本人。管理者は他人の `name`・`email` の更新と削除 |
| `requests/{id}` | 依頼 | `requesterId`、`editorId`、`status`、`title`、`brief`、`dueDate`、`attachments`、`reviewRound`、`submissionCount`、`approvedVersion` ほか | 承認済みのスタッフ、依頼者本人 | 依頼者が作成。状態の変更は役割と状態で制限 |
| `requests/{id}/submissions/{sid}` | 提出動画 | `version`、`name`、`path`、`size`、`uploadedBy`、`createdAt` | 依頼と同じ | 担当編集者 |
| `requests/{id}/revisions/{rid}` | 修正指示 | `version`、`instruction`、`createdBy`、`createdAt` | 依頼と同じ | 依頼者 |
| `notifications/{id}` | 通知 | `requestId`、`type`、`audience`、`recipientId`、`actorId`、`message`、`createdAt` | 宛先の本人、`audience` が `editors` なら編集者 | 依頼の操作と同時に作成 |

動画・資料の実体は Storage（`storage.rules`）：`uploads/{uid}/{requestId}/…`（依頼者）、`videos/{requestId}/{version}/…`（編集者）。

## 最初の管理者

管理者はアプリからは作れないので、最初の1人だけ Firebase コンソールで登録します。

1. Authentication で、その人のアカウントを作成（またはアプリで一度ログイン）して、UID を控える。
2. Firestore の `roles` に、ドキュメントID＝その UID で作成する。
   - `role`（string）：`staff`
   - `manager`（boolean）：`true`
3. 以降は、アプリの「スタッフ管理」から招待・権限変更・削除ができる。

## 日々の運用

- スタッフの追加：スタッフ管理の「＋」から招待メールを送る。受け取った人が登録すると、招待どおりの権限が付く。
- 権限の変更・削除：スタッフカードの3点メニューから。削除は `roles` と `users` を消す（ログインアカウントは残り、再ログインすると「承認待ち」になる）。
- 検索条件は1項目だけなので、複合インデックスは不要。複合条件の検索を足したら `firestore.indexes.json` に追加する。
- ルールを変えたら `firebase deploy --only firestore:rules` で反映する。エミュレータで試すには Java が必要。
