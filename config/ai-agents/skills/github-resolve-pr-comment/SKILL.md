---
name: github-resolve-pr-comment
description: PRのレビューコメントを確認し、対応・返信するSkill。
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*), Bash(jq:*), Bash(mktemp:*), Bash(bash:*), Write
---

# Resolve PR Review Comments

## 引数

- `PR number`: 対応するPR番号（任意、デフォルトは現在のブランチのPR）

対応後は**常に**GitHubへリプライコメントを投稿する。
inline review thread / conversation は `isResolved` を基準にし、すべての unresolved thread を対応対象にする。
review 全体の state や `isOutdated` だけで対応対象から除外しない。

## コメントの種類と扱い

PR には性質の異なる3種類のコメントがある。**それぞれ取得方法もリプライ方法も違う**ので混同しないこと。

- **Review thread (inline)**: コードの行に紐づくスレッド。最も一般的なレビューコメント。
  - 取得方法: GraphQL `reviewThreads` ([fetch_review_threads.sh](scripts/fetch_review_threads.sh))
  - リプライ先: `repos/{owner/repo}/pulls/{pr}/comments/{root-comment-id}/replies` に thread 内コメントとして追記
  - **重要**: inline スレッドへのリプライには **スレッドの先頭コメントの `databaseId`**（root comment id）を使うこと。スレッド内の途中コメントのIDではない。`fetch_review_threads.sh` は `root_comment_id` フィールドにこのIDを入れて返す。
- **Review summary body**: レビュー全体に付く本文。`COMMENTED` / `CHANGES_REQUESTED` などの state を持つ。
  - 取得方法: `gh pr view <pr> --json reviews`
  - リプライ先: ネイティブなスレッド機構はないため、引用形式の issue comment として投稿
- **Issue comment (PR-level)**: コード行に紐づかない PR 全体への一般コメント。
  - 取得方法: `gh pr view <pr> --json comments` または `gh api /issues/{pr}/comments`
  - リプライ先: `repos/{owner/repo}/issues/{pr}/comments` に新規 issue comment として投稿

## タスク

### Phase 0: 事前チェックと言語検出

- PRの特定:
  - 現在のブランチ、PR情報、PRタイトル、PR本文を確認する
  - 引数にPR番号が指定されている場合はそのPRを使用する
  - 指定がない場合は、現在のブランチに紐づくPRを使用する: `gh pr view --json number --jq '.number'`
  - PRが存在しない場合はエラーメッセージを表示して中止する
- リポジトリ情報:
  - `owner/repo` を取得する: `gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'`
- 言語検出:
  - PRのタイトルと本文を分析して言語を検出する（例: 日本語、英語）
  - すべてのコミットメッセージとリプライコメントは検出された言語で記述する
  - 言語が曖昧な場合は英語をデフォルトとする

### Phase 1: コメントの取得

以下を**並列に**実行する。

- **全 unresolved review thread を取得**（inline コメント）:

  ```bash
  bash <skill-dir>/scripts/fetch_review_threads.sh \
    --repo "<owner/repo>" \
    --pr <number> \
    --only-unresolved > /tmp/pr-<number>-respond-threads.json
  ```

  - `--only-unresolved` は `isResolved=false` の thread を返す。`isOutdated=true` でも unresolved なら対象に含める
  - 各スレッドは `thread_id` / `path` / `line` / `root_comment_id` / `comments[]` を持つ
  - **重要**: リプライ先のコメントIDは必ず `root_comment_id`（スレッド先頭コメントの `databaseId`）を使う

- **Review summary body を取得**:

  ```bash
  gh pr view <number> --json reviews \
    --jq '.reviews | map(select(.state != "APPROVED" and (.body | length) > 0))' \
    > /tmp/pr-<number>-respond-reviews.json
  ```

  - 自分のレビューは除外する（自分自身に返信しない）
  - `state == "APPROVED"` で本文が空のものは「LGTM」相当なので除外する

- **PR-level issue comments を取得**:

  ```bash
  gh pr view <number> --json comments \
    --jq '.comments' > /tmp/pr-<number>-respond-issue-comments.json
  ```

  - すでに対応済みかどうかは内容と時系列で判断する（issue comment にはネイティブな解決機構がない）

### Phase 2: コメントの分類と集約

複数レビュー・複数コメントを横断して整理する。**最新のレビューだけでなく、過去のレビューや issue comment も含めて全件を対象にする**。

**集約ルール**:

- 同一の話題が複数箇所に存在する場合は1件にまとめ、対応先は inline review thread を優先する
- 同一レビュアーの後続発言で **明示的に撤回** された指摘は除外する（撤回が不明確な場合は対象に残す）
- 既に他 thread や過去コミットで対応済みの内容は、対応済みとしてマークし、リプライのみ準備する

集約後、次のように分類する（inline review thread は全 unresolved thread を対象にし、review 全体の state では除外しない）。

- **Must Fix候補**: このPRの正しさや安全性に関わり、必ず対応すべき可能性があるコメント
- **Should Fix候補**: 改善提案や任意対応の可能性があるコメント
- **質問**: 明確化を求めるコメント
- **情報共有**: 対応不要のコメント

### Phase 3: Must Fix / Should Fix の判断

レビューコメントの重要度を Must Fix / Should Fix に分け、対応方針を決定する。

- **Must Fix**:
  - このPRの正しさ、仕様、テスト、CI、型安全性、セキュリティ、重大な保守性に関わる指摘
  - レビューコメントが `Must Fix` / `must` / `blocking` / `required` と明示している指摘
  - 原則として必ず対応する。対応できない場合は、理由を明確にして議論コメントを返し、未解決として扱う
- **Should Fix**:
  - 改善提案、設計・可読性・スタイルの提案、将来対応でもよい指摘
  - レビューコメントが `Should Fix` / `should` / `suggestion` / `nit` と明示している指摘
  - レビュイー側で妥当性、リスク、スコープ、費用対効果を判断して採用/不採用を決める
- **質問 / 情報共有**:
  - 明確化が必要な質問には回答する
  - 対応不要な情報共有には、必要に応じて確認済みであることを返信する

判断時は次を確認する:

- レビュアーの理解は正しいか
- 提案はこのPRで実装すべきか
- 変更により副作用やスコープ逸脱が発生しないか
- 採用しない場合に説明できる技術的根拠があるか

### Phase 4: コメントへの対応

- **Must Fix**:
  - 対象ファイルと行に移動し、指摘された問題を必ず修正する
  - 修正できない場合は、技術的理由、代替案、確認したい点をリプライとして準備する
- **Should Fix**:
  - 採用する場合は実装し、変更内容をリプライで説明する
  - 採用しない場合は、スコープ、リスク、既存設計、費用対効果などの理由を明確に返信する
- **質問**:
  - 検出された言語で明確に回答する
- **情報共有**:
  - 必要に応じて確認済みであることを返信する

### Phase 5: コミットとプッシュ

検出された言語でコミットメッセージを記述してコミット・プッシュする。
コード変更が一切ない場合（質問への回答のみ等）はこのフェーズをスキップする。

### Phase 6: リプライの投稿

対応した各コメントへのリプライを**常に**投稿する。
リプライ先により使用するスクリプトが異なる。

#### 6-A. Inline review thread へのリプライ

コード行に紐づく review thread に対するリプライ。**全 unresolved thread にリプライする**。

スレッド内コメントとして追記される。使用するスクリプトは [post_review_reply.sh](scripts/post_review_reply.sh)。

リプライ本文はアクションに応じて内容を変える:

- **採用・実装済み**: 変更内容 + コミット参照（短い SHA）
  - 英語: `Fixed in abc1234. Changed X to Y as suggested.`
  - 日本語: `abc1234 で修正しました。ご指摘の通り X を Y に変更しました。`
- **議論が必要**: 自分の見解 + 根拠 + 質問
  - 英語: `Thanks for the suggestion! I chose X because [reason]. However, I see your point about Y. Could you clarify [question]?`
  - 日本語: `ご提案ありがとうございます。[理由] のため X を選択しましたが、Y についてのご指摘も理解できます。[question] について教えていただけますか？`
- **不採用**: 提案を採用しなかった理由の明確な説明
  - 英語: `I'd like to keep this as-is because [technical reason]. ...`
  - 日本語: `[技術的な理由] のため、現状維持としたいです。...`

手順:

1. リプライ本文を Markdown ファイルに書き出す（Write tool 使用）
   - 出力先: `/tmp/pr-reply-<root-comment-id>.md`
2. `post_review_reply.sh` で投稿する
   - `<root-comment-id>` は `fetch_review_threads.sh` の出力の `root_comment_id` を使う（スレッド先頭コメントの `databaseId`）

```bash
bash <skill-dir>/scripts/post_review_reply.sh \
  --repo "<owner/repo>" \
  --pr <number> \
  --review-comment-id <root-comment-id> \
  --body-file /tmp/pr-reply-<root-comment-id>.md
```

#### 6-B. PR-level コメントの投稿

PR 全体への対応サマリーを**1つの issue comment として投稿する**。使用するスクリプトは [post_issue_comment.sh](scripts/post_issue_comment.sh)。

本文の構成:

- **概要**: 対応した未解決スレッド総数、修正件数、不採用件数、結果状態を1〜2文で記述
- **対応した内容の箇条書き**: Must Fix / Should Fix / 質問 / 情報共有 ごとに、対応した inline review thread を1件ずつ列挙する
  - 各項目は対応した inline review comment への URL リンク（`[filename:line](review-comment-url)` 形式）で参照する
  - 採用・不採用・修正コミット SHA・理由などの事実を客観的に記述する

template:

- English: [`references/comment_summary_template.md`](references/comment_summary_template.md)
- Japanese: [`references/comment_summary_template_ja.md`](references/comment_summary_template_ja.md)

記述ルール:

- **人間との対話を意識しない**。「ご指摘の通り」「ありがとうございます」などの対話的な表現は使わず、事実と内容のみを客観的に書く
- Review summary body / PR-level issue comment への個別リプライ（引用＋回答）はこのコメントには含めない。サマリーのみを投稿する

手順:

1. 上記内容を1つの Markdown ファイルに書き出す
   - 出力先: `/tmp/pr-summary-<number>.md`
2. `post_issue_comment.sh` で投稿する

```bash
bash <skill-dir>/scripts/post_issue_comment.sh \
  --repo "<owner/repo>" \
  --pr <number> \
  --body-file /tmp/pr-summary-<number>.md
```

### Phase 7: 結果を返す

Phase 6-B で投稿した PR-level コメント（コメントサマリー）の本文をそのまま出力する。

## 注意事項

- コメントの意図が不明確な場合は、変更前にユーザーに確認を求める
- 大きな設計変更の場合は、実装前にユーザーと相談する
- 関連する変更は論理的なコミットにグループ化する
- **批判的思考が不可欠**: すべてのレビューコメントが正しいとは限らない。レビュアーも間違えることがある。常に客観的にコメントを評価すること
- レビュアーと意見が異なる場合は、敬意を持って具体的な技術的根拠を提示する
- 解決済みのスレッド (`isResolved=true`) はスキップする。`isOutdated=true` は単独では除外条件にせず、unresolved なら対応対象に含める
- リプライ本文は**必ずファイル経由**で渡す。`-f body=...` や `--body "..."` でのシェル引数渡しは禁止
- inline スレッドへのリプライ先 ID は**スレッドの先頭コメントの `databaseId`**（`root_comment_id`）を使う。スレッド内途中のコメントIDだと 404 になる
