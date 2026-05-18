---
name: github-pr-respond-comment
description: PRのレビューコメントを確認し、対応・返信するSkill。
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*), Bash(jq:*), Bash(mktemp:*), Bash(bash:*), Write
---

# レビューコメントへの対応

## 引数

- `PR number`: 対応するPR番号（任意、デフォルトは現在のブランチのPR）
- `--reply`: 対応後にGitHubにリプライコメントを投稿（任意）

## コンテキスト

以下を取得してから作業を開始してください。

- 現在のブランチ: `git branch --show-current`
- 現在のPR: `gh pr view --json number,url,reviewDecision 2>/dev/null || echo "No PR found"`
- PRタイトル: `gh pr view --json title --jq '.title' 2>/dev/null`
- PR本文: `gh pr view --json body --jq '.body' 2>/dev/null | head -30`
- リポジトリ: `gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'`

## コメントの種類と扱い

PR には性質の異なる3種類のコメントがある。**それぞれ取得方法もリプライ方法も違う**ので混同しないこと。

| 種類                         | 説明                                       | 取得方法                                                                  | リプライ先                                                                          |
| ---------------------------- | ------------------------------------------ | ------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| **Review thread (inline)**   | コードの行に紐づくスレッド（最も一般的）   | GraphQL `reviewThreads` ([fetch_review_threads.sh](scripts/fetch_review_threads.sh)) | `repos/{owner/repo}/pulls/{pr}/comments/{root-comment-id}/replies` (thread内に追記) |
| **Review summary body**      | レビュー全体に付く本文（state付き）        | `gh pr view <pr> --json reviews`                                          | スレッド機構なし。引用形式で issue comment として返す                               |
| **Issue comment (PR-level)** | コード行に紐づかない PR 全体への一般コメント | `gh pr view <pr> --json comments` または `gh api /issues/{pr}/comments`   | `repos/{owner/repo}/issues/{pr}/comments` に新規 issue comment を投稿               |

**重要**: inline スレッドへのリプライには **スレッドの先頭コメントの `databaseId`**（root comment id）を使うこと。スレッド内の途中コメントのIDではない。`fetch_review_threads.sh` は `root_comment_id` フィールドにこのIDを入れて返す。

## タスク

### Phase 0: 事前チェック

1. 引数にPR番号が指定されている場合はそのPRを使用する
2. そうでなければ、現在のブランチに紐づくPRを使用する: `gh pr view --json number --jq '.number'`
3. PRが存在しない場合はエラーメッセージを表示して中止する
4. `owner/repo` を取得する: `gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'`
5. `--reply` フラグの有無を保持する

### Phase 1: PR言語の検出

- PRのタイトルと本文を分析して言語を検出する（例: 日本語、英語）
- **重要**: すべてのコミットメッセージとリプライコメントは検出された言語で記述すること
- 言語が曖昧な場合は英語をデフォルトとする

### Phase 2: コメントの取得

以下を**並列に**実行する。

1. **未解決の review thread を取得**（inline コメント）:

   ```bash
   bash <skill-dir>/scripts/fetch_review_threads.sh \
     --repo "<owner/repo>" \
     --pr <number> \
     --only-unresolved > /tmp/pr-respond-threads.json
   ```

   - `--only-unresolved` を付けると `isResolved=true` および `isOutdated=true` のスレッドが除外される
   - 各スレッドは `thread_id` / `path` / `line` / `root_comment_id` / `comments[]` を持つ
   - **重要**: リプライ先のコメントIDは必ず `root_comment_id`（スレッド先頭コメントの `databaseId`）を使う

2. **Review summary body を取得**:

   ```bash
   gh pr view <number> --json reviews \
     --jq '.reviews | map(select(.state != "APPROVED" and (.body | length) > 0))' \
     > /tmp/pr-respond-reviews.json
   ```

   - 自分のレビューは除外する（自分自身に返信しない）
   - `state == "APPROVED"` で本文が空のものは「LGTM」相当なので除外する

3. **PR-level issue comments を取得**:

   ```bash
   gh pr view <number> --json comments \
     --jq '.comments' > /tmp/pr-respond-issue-comments.json
   ```

   - 自分のコメントは除外する
   - すでに対応済みかどうかは内容と時系列で判断する（issue comment にはネイティブな解決機構がない）

### Phase 3: コメントの分類

取得した未対応コメントを次のように分類する:

- **要修正**: コード変更を要求するコメント
- **要議論**: 設計判断や見解の相違があり、即座に修正しない方が良いコメント
- **質問**: 明確化を求めるコメント
- **提案**: 任意の改善案
- **情報共有**: 対応不要のコメント

### Phase 4: コメントサマリーの表示

検出された言語で次のフォーマットで表示する。

#### 英語フォーマット

```markdown
## Review Comments Summary

### ✅ Requires Code Change (X items)

1. **[filename:line]** by @reviewer
   > Comment content
   > → Proposed action: ...

### 💬 Requires Discussion (X items)

1. **[filename:line]** by @reviewer
   > Comment content
   > → Concern: [why this needs discussion]
   > → Your position: [your perspective with reasoning]

### Questions (X items)

1. **[filename:line]** by @reviewer
   > Question content
   > → Proposed answer: ...

### Suggestions (X items)

1. **[filename:line]** by @reviewer
   > Suggestion content
   > → Accept / Decline with reason: ...
```

#### 日本語フォーマット

```markdown
## レビューコメント一覧

### ✅ 要修正 (X件)

1. **[ファイル名:行番号]** by @reviewer
   > コメント内容
   > → 対応方針: ...

### 💬 要議論 (X件)

1. **[ファイル名:行番号]** by @reviewer
   > コメント内容
   > → 懸念点: [議論が必要な理由]
   > → 見解: [技術的な根拠を含めた自分の立場]

### 質問 (X件)

1. **[ファイル名:行番号]** by @reviewer
   > 質問内容
   > → 回答案: ...

### 提案 (X件)

1. **[ファイル名:行番号]** by @reviewer
   > 提案内容
   > → 採用/不採用の理由: ...
```

### Phase 5: コメントの妥当性を評価

コメントを受け入れる前に、正確性と関連性を批判的に評価する。考慮すべき点:

- レビュアーの理解は正しいか？
- 提案は実際にコードを改善するか？
- レビュアーが考慮していないトレードオフはないか？
- 個人の好みの問題か、客観的な改善か？

**不正確または議論の余地があるコメント**の場合:

- 変更をすぐに実装しない
- 代わりに、自分の見解を説明する丁寧なリプライを準備する
- 技術的な根拠、参考資料、または例を提示して立場を裏付ける
- レビュアーの意図が不明確な場合は明確化の質問をする
- 議論が解決するまで変更を待つ

コメントを以下のようにマークする:

- ✅ **採用**: コメントは妥当であり実装すべき
- 💬 **議論**: アクション前に議論が必要
- ❌ **不採用**: コメントが不正確（明確な理由を提示）

### Phase 6: 採用したコメントへの対応

- **コード変更の場合**: 対象ファイルと行に移動し、要求された変更を適用する
- **質問の場合**: 明確な回答を準備する（検出された言語で）
- **提案の場合**: 有益であれば適用、そうでなければ理由を説明する

### Phase 7: コミットとプッシュ

検出された言語でコミットメッセージを記述してコミット・プッシュする。

```bash
git add -A
# 英語: fix: address review comments
# 日本語: fix: レビューコメントに対応
git commit -m "<message>"
git push
```

コード変更が一切ない場合（質問への回答のみ等）はこのフェーズをスキップする。

### Phase 8: リプライの投稿（`--reply` 指定時のみ）

`--reply` が指定されていない場合はこのフェーズをスキップする。

各コメントごとに、リプライ本文を**必ずファイルに書き出してから** [post_reply.sh](scripts/post_reply.sh) を呼び出す。
**禁止**: `gh api -f body="..."` のように本文をシェル引数に直接渡すこと。改行・引用符・バッククォート等の escape が壊れる原因になる。

#### Inline review thread へのリプライ

```bash
# 1. リプライ本文を Markdown ファイルに書き出す（Write tool 使用）
#    → /tmp/pr-reply-<root-comment-id>.md

# 2. post_reply.sh で投稿（root_comment_id は fetch_review_threads.sh の出力から取る）
bash <skill-dir>/scripts/post_reply.sh \
  --repo "<owner/repo>" \
  --pr <number> \
  --review-comment-id <root-comment-id> \
  --body-file /tmp/pr-reply-<root-comment-id>.md
```

#### Review summary body / PR-level issue comment へのリプライ

スレッド機構がないため、引用形式の新規 issue comment として投稿する。

```bash
# 1. リプライ本文を Markdown ファイルに書き出す。
#    冒頭で対象コメント（@author の発言）を Markdown の引用 (>) で引用する。
#    → /tmp/pr-reply-issue-<seq>.md

# 2. post_reply.sh の --issue-comment モードで投稿
bash <skill-dir>/scripts/post_reply.sh \
  --repo "<owner/repo>" \
  --pr <number> \
  --issue-comment \
  --body-file /tmp/pr-reply-issue-<seq>.md
```

#### リプライ本文の内容

アクションに応じて内容を変える:

- **採用・実装済み**: 変更内容 + コミット参照（短い SHA）
  - 英語: `Fixed in abc1234. Changed X to Y as suggested.`
  - 日本語: `abc1234 で修正しました。ご指摘の通り X を Y に変更しました。`
- **議論が必要**: 自分の見解 + 根拠 + 質問
  - 英語: `Thanks for the suggestion! I chose X because [reason]. However, I see your point about Y. Could you clarify [question]?`
  - 日本語: `ご提案ありがとうございます。[理由] のため X を選択しましたが、Y についてのご指摘も理解できます。[question] について教えていただけますか？`
- **不採用**: 提案を採用しなかった理由の明確な説明
  - 英語: `I'd like to keep this as-is because [technical reason]. ...`
  - 日本語: `[技術的な理由] のため、現状維持としたいです。...`

### Phase 9: 結果を返す

検出された言語で次を返す:

- 実行したアクションのサマリー（修正件数 / 投稿リプライ件数）
- 投稿に成功した URL の一覧
- 議論待ちのコメント一覧（レビュアーの返答待ち）
- 手動対応が必要なコメント一覧（ある場合）
- すべてのブロッキングコメントに対応済みの場合、再レビューの依頼を提案する
- **注意**: 議論待ちのコメントがある場合は、再レビュー依頼前にレビュアーの返答を待つことを推奨する

## 注意事項

- コメントの意図が不明確な場合は、変更前にユーザーに確認を求める
- 大きな設計変更の場合は、実装前にユーザーと相談する
- 関連する変更は論理的なコミットにグループ化する
- **批判的思考が不可欠**: すべてのレビューコメントが正しいとは限らない。レビュアーも間違えることがある。常に客観的にコメントを評価すること
- レビュアーと意見が異なる場合は、敬意を持って具体的な技術的根拠を提示する
- 解決済みのスレッド (`isResolved=true`) と outdated なスレッド (`isOutdated=true`) は完全にスキップする — 再対応の必要なし
- リプライ本文は**必ずファイル経由**で渡す。`-f body=...` や `--body "..."` でのシェル引数渡しは禁止
- inline スレッドへのリプライ先 ID は**スレッドの先頭コメントの `databaseId`**（`root_comment_id`）を使う。スレッド内途中のコメントIDだと 404 になる
