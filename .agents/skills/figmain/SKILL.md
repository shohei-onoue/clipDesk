---
name: figmain
description: Figmaのノード情報からFlutterウィジェットを生成し、指定ファイルに反映する
arguments:
  - name: url
    description: FigmaのノードURL
    required: true
  - name: path
    description: "反映先のDartファイルパス (例: lib/screens/figmaTest.dart)"
    required: true
---

Figma MCPツールを使用して、以下のFigmaデザインからFlutterウィジェットを生成し、指定のファイルに書き込んでください。

**入力情報**
* Figma URL: $1
* 反映先パス: $2

**実行手順**
1. **ノード情報取得**
   - Figma URLから `fileKey` と `node-id`（ハイフン形式 `4-43` は `4:43` に置換）を特定する。
   - 接続済みの Figma MCP ツールを実行してノードのツリー構造、サイズ、余白、色、フォント情報を取得する。
   - 取得に失敗した場合はノードIDの形式を再確認してMCPを再試行し、ローカルサーバー（localhost）へのフォールバックは行わない。

2. **Flutterコード生成**
   - 無駄な多重ネスト（不要なContainerやStackの乱用）を避け、軽量・高速に動作するウィジェットツリーを構築する。
   - Figmaのサイズ、パディング、角丸、HEXカラー値を正確に反映する。
   - 共通化できるUI部品がある場合は、必要最小限の独立したStatelessWidgetとして切り出す。

3. **ファイル反映**
   - `$2` で指定されたファイルパスに直接コードを出力（新規作成または上書き）する。
   - 必要なインポート文（`package:flutter/material.dart` 等）を漏れなく含める。
   - `$2` 以外のファイルは編集・改変しない。
