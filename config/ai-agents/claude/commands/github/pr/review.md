---
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*), Bash(jq:*)
argument-hint: [PR number]
description: GitHubのpull request(PR)のコードレビューを行うSkill。5つの専門レビュアーagentを並列実行し、統合レビューレポートとインラインコメントを生成する。
---

# Pull Request Review（オーケストレーション）

5つの専門レビュアー agent を並列実行し，結果を統合してレビューレポートを生成する．

## Arguments

- `PR number`: レビューするPR番号 (optional, defaults to PR for current branch)

## Task

### Phase 1: 事前チェック + PR情報収集

1. **事前チェック**:
   - `$ARGUMENTS` にPR番号が指定されている場合は `gh pr view <number>` を使用
   - 指定がない場合は現在のブランチに紐づくPRを使用
   - PRが存在しない場合はエラーメッセージを表示して中断

2. **PR情報を収集する**:
   - PRメタデータの取得: `gh pr view <number> --json title,body,baseRefName,headRefName,author,additions,deletions,changedFiles`
   - 変更ファイル一覧の取得: `gh pr view <number> --json files --jq '.files[].path'`
   - diff の取得: `gh pr diff <number>`
   - 最新の commit SHA の取得: `gh pr view <number> --json commits --jq '.commits[-1].oid'`

3. **言語検出**:
   - PRのタイトルと本文を分析して言語を検出する（例: 日本語、英語、中国語）
   - **重要**: すべてのレビューコメントとレポートは、検出された言語で記述すること
   - 言語が曖昧な場合は、英語をデフォルトとする

4. **PR の目的を要約する**:
   - タイトルと説明文からPRの目的を1-2文で要約する
   - この要約を各 agent に渡す

### Phase 2: 5つのレビュアー agent を並列実行

Taskツールを使い，以下の5つのagentを**すべて同時に並列起動**すること．

各 agent には以下の情報を渡す:

- PRの目的（Phase 1 で作成した要約）
- diff の全文
- 変更ファイル一覧
- 使用言語（検出された言語）

#### Agent 1: code-quality-reviewer

```yaml
subagent_type: code-quality-reviewer
```

PRの diff を分析し，コード品質の観点でレビューしてください．
PRの出力形式セクションに従って Must Fix / Should Fix / Good Points で結果を出力してください．

#### Agent 2: documentation-accuracy-reviewer

```yaml
subagent_type: documentation-accuracy-reviewer
```

PRの diff を分析し，ドキュメントの正確性・完全性の観点でレビューしてください．
PRの出力形式セクションに従って Must Fix / Should Fix / Good Points で結果を出力してください．

#### Agent 3: performance-reviewer

```yaml
subagent_type: performance-reviewer
```

PRの diff を分析し，パフォーマンスの観点でレビューしてください．
PRの出力形式セクションに従って Must Fix / Should Fix / Good Points で結果を出力してください．

#### Agent 4: security-reviewer

```yaml
subagent_type: security-reviewer
```

PRの diff を分析し，セキュリティの観点でレビューしてください．
PRの出力形式セクションに従って Must Fix / Should Fix / Good Points で結果を出力してください．

#### Agent 5: testing-reviewer

```yaml
subagent_type: testing-reviewer
```

PRの diff を分析し，テストの観点でレビューしてください．
PRの出力形式セクションに従って Must Fix / Should Fix / Good Points で結果を出力してください．

### Phase 3: 結果統合 + レビューレポート生成

1. **5つの agent の結果を統合する**:
   - 各 agent の Must Fix / Should Fix / Good Points を集約する
   - 重複する指摘を統合する（同じファイル・行への指摘がある場合）

2. **Mergeの判定を行う**:
   - Must Fix が1件以上 → `REQUEST_CHANGES`
   - Must Fix が0件で Should Fix が1件以上 → `COMMENT`
   - 指摘なし → `APPROVE`

3. **レビューレポートを生成する**:
   - 検出された言語に応じた適切なテンプレートを使用する
   - 後述の [レビューレポートテンプレート](#レビューレポートテンプレート) を参照
   - **重要**: "Must Fix" および "Should Fix" の項目には，inline comment の投稿を可能にするため `` `filepath:line` `` の形式を正確に使用すること
   - 各項目にはどの観点（code-quality, documentation, performance, security, testing）からの指摘かを明記すること

4. **レビューレポートを表示する**:
   - 検出された言語でレビューレポートを表示する

5. **GitHub への投稿を確認する**:
   - AskUserQuestion ツールを使い，レビューを GitHub に投稿するかユーザーに確認する
   - ユーザーが投稿を選択した場合:
     - レビューレポートの "Must Fix" および "Should Fix" セクションから inline comments を抽出する
     - `gh api` を使用して reviews endpoint に投稿する（[inline comments 付きレビューの投稿](#inline-comments-付きレビューの投稿) を参照）
     - 投稿後にPRの URL を表示する
   - ユーザーが投稿しないを選択した場合:
     - そのまま終了する

## リファレンス

### レビューレポートテンプレート

#### 英語テンプレート

```markdown
# <img src="https://github.com/claude.png?size=32" alt="Claude Icon" width="32" height="32" style="vertical-align:middle; margin-right:8px;" /> Claude Review Pull Request

## Summary

<!-- 1-2 sentence summary of what this PR does -->

## Good Points

- <!-- Positive aspects of the implementation -->

## Must Fix

- `filename:line` - [category] Description of the issue

## Should Fix

- `filename:line` - [category] Description of the suggestion

## Suggestion

## Verdict

<!-- APPROVE / REQUEST_CHANGES / COMMENT -->

---

Reviewed by Claude
```

#### 日本語テンプレート

```markdown
# <img src="https://github.com/claude.png?size=32" alt="Claude Icon" width="32" height="32" style="vertical-align:middle; margin-right:8px;" /> Claude Review Pull Request

## Summary(概要)

<!-- 1-2 sentence summary of what this PR does -->

## Good Points(良い点)

- <!-- Positive aspects of the implementation -->

## Must Fix(要修正)

- `filename:line` - [category] Description of the issue

## Should Fix(修正推奨)

- `filename:line` - [category] Description of the suggestion

## Suggestion(提案)

## Verdict(判定)

<!-- APPROVE / REQUEST_CHANGES / COMMENT -->

---

Reviewed by Claude
```

### カテゴリ表記

| Agent                           | 英語表記      | 日本語表記     |
| ------------------------------- | ------------- | -------------- |
| code-quality-reviewer           | code-quality  | コード品質     |
| documentation-accuracy-reviewer | documentation | ドキュメント   |
| performance-reviewer            | performance   | パフォーマンス |
| security-reviewer               | security      | セキュリティ   |
| testing-reviewer                | testing       | テスト         |

### Inline comments 付きレビューの投稿

ユーザーが GitHub への投稿を選択した場合:

#### ステップ 1: レポートから inline comments を抽出する

"Must Fix" / "要修正" および "Should Fix" / "提案" セクションから項目を抽出する。

パターン: `` `filepath:line` - comment ``

#### ステップ 2: GitHub API 経由でレビューを投稿する

**Endpoint**: `POST /repos/{owner}/{repo}/pulls/{pull_number}/reviews`

**Request body**:

```json
{
  "body": "Review summary...",
  "commit_id": "<latest commit SHA>",
  "event": "REQUEST_CHANGES",
  "comments": [
    {
      "path": "src/auth.ts",
      "line": 42,
      "body": "🔴 **Must Fix**: Null check is required\n\n---\nCommented by Claude"
    }
  ]
}
```

`gh api` を使用してレビューを投稿する。

### セクション別コメント prefix

| セクション | 英語 Prefix       | 日本語 Prefix |
| ---------- | ----------------- | ------------- |
| Must Fix   | 🔴 **Must Fix**:   | 🔴 **要修正**: |
| Should Fix | 💡 **Suggestion**: | 💡 **提案**:   |

### Event type

| 判定            | Event             |
| --------------- | ----------------- |
| APPROVE         | `APPROVE`         |
| REQUEST_CHANGES | `REQUEST_CHANGES` |
| COMMENT         | `COMMENT`         |

### 注意事項

- 行番号は新しいファイル（diff の右側）に対応するものでなければならない
- inline として投稿できないコメント（例: diff に含まれない行）は、body に含める
- 1回のレビューにつき inline comments は最大50件まで
