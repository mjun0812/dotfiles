---
name: github-pr-review
description: GitHubのpull request(PR)のコードレビューを行うSkill。worktreeを作成してソースコード全体を読みながら5つの専門レビュアーagentを並列実行し、統合レビューレポートとMust Fixのインラインコメントを生成する。self reviewにも対応する。
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*), Bash(jq:*), Bash(mkdir:*), Bash(rm:*), Bash(test:*), Bash(basename:*)
---

# Pull Request Review（オーケストレーション）

PRのhead commitを worktree にチェックアウトし，5つの専門レビュアー agent を並列実行する．各 agent はworktree内の実際のソースコードを参照しながらレビューを行う．結果を統合してレビューレポートを生成し，Must Fix の項目のみ inline comment として投稿する．

## Arguments

- `PR number`: レビューするPR番号 (optional, defaults to PR for current branch)

## Task

### Phase 1: 事前チェック + PR情報収集 + worktree 作成

1. **事前チェック**:
   - **引数にPR番号が指定されている場合**: `gh pr view <number>` で対象PRを取得する
   - **引数なしで，現在のブランチに紐づく open PR が存在する場合**: そのPRをそのまま使用する（確認なし）
     - 判定方法: `gh pr view --json number,state 2>/dev/null` の終了コードと `state == "OPEN"` で判断する
   - **引数なしで，現在のブランチに紐づく open PR が存在しない場合**: AskUserQuestion でユーザーに対象PRを確認する
     - `gh pr list --state open --json number,title,headRefName,author --limit 20 --jq 'sort_by(.number) | reverse'` で最新の open PR 一覧を取得する
     - 取得した上位 PR を AskUserQuestion の選択肢として提示する（label例: `#123 Fix auth bug (feature/auth-fix)`）
       - 1件のみの場合: そのPRと「キャンセル」の2択
       - 2-3件: そのまま選択肢に並べる
       - 4件以上: 最新3件を提示し，4つ目は「キャンセル」（ユーザーは "Other" で任意のPR番号を直接入力できる）
     - open PR が0件の場合はエラーメッセージを表示して中断する
     - ユーザーが「キャンセル」を選択した場合は中断する

2. **PR情報を収集する**:
   - PRメタデータの取得: `gh pr view <number> --json title,body,baseRefName,headRefName,author,additions,deletions,changedFiles`
   - 変更ファイル一覧の取得: `gh pr view <number> --json files --jq '.files[].path'`
   - diff の取得: `gh pr diff <number>`
   - 最新の commit SHA の取得: `gh pr view <number> --json commits --jq '.commits[-1].oid'`
   - PR author の取得: `gh pr view <number> --json author --jq '.author.login'`

3. **言語検出**:
   - PRのタイトルと本文を分析して言語を検出する（例: 日本語、英語、中国語）
   - **重要**: すべてのレビューコメントとレポートは、検出された言語で記述すること
   - 言語が曖昧な場合は、英語をデフォルトとする

4. **既存レビューの確認**:
   - 現在の GitHub ユーザー名を取得: `gh api user --jq '.login'`
   - PRの既存レビュー一覧を取得: `gh api repos/{owner}/{repo}/pulls/{pull_number}/reviews --jq '.[] | select(.user.login == "<current_user>") | {id, state, submitted_at}'`
   - 自分の既存レビューがある場合は，その情報（レビューID，state，投稿日時）を Phase 3 で使用するために保持する

5. **self review 判定**:
   - PR author と現在の GitHub ユーザー名を比較する
   - 一致する場合は「self review モード」として扱い，Phase 3 でAPI投稿時の `event` 変換に使用する（後述）
   - GitHubの仕様上，自分のPRに対して `APPROVE` / `REQUEST_CHANGES` は投稿できないため，self review では API event を `COMMENT` に変換する必要がある（ただしレポート上の Verdict は 2択のまま）

6. **worktree の作成**:
   - レビュアー agent が実際のソースコードを参照できるよう，PRの head commit を worktree にチェックアウトする
   - リポジトリ名を取得: `gh repo view --json name --jq '.name'`
   - worktree のパス: `/tmp/claude-pr-review/<repo-name>-<pr-number>`
   - 既存の worktree がある場合は事前に削除する: `git worktree remove --force <path> 2>/dev/null; rm -rf <path>`
   - head commit を fetch する: `git fetch origin <head-sha>` （`<head-sha>` は Phase 1.2 で取得した最新 commit SHA）
   - detached HEAD で worktree を作成する: `git worktree add --detach <path> <head-sha>`
     - detached を使う理由: ローカルブランチを作らず，後続のクリーンアップを単純化するため
   - worktree のパスを以降の Phase 2 / Phase 3 で使用するために保持する
   - **重要**: worktree は Phase 4 (cleanup) で必ず削除する。Phase 2/3 で予期せぬエラーが発生した場合も同様

### Phase 2: 5つのレビュアー agent を並列実行

Taskツールを使い，以下の5つのagentを**すべて同時に並列起動**すること．

各 agent には以下の情報を渡す:

- PRの目的（タイトル・本文から1-2文で要約）
- diff の全文
- 変更ファイル一覧
- **worktree のパス（絶対パス）**: agent はこのディレクトリ内のファイルを Read/Grep/Glob で参照し，diff だけでなくソースコード全体の文脈を踏まえてレビューする
- 使用言語（検出された言語）

各 agent への指示には以下を必ず含める:

> diff だけでなく，worktree (`<worktree-path>`) 内の実際のソースコードを参照してレビューしてください．関連する周辺コード，呼び出し元，型定義，テストなども必要に応じて読み，変更の妥当性を判断してください．

#### Agent 1: code-quality-reviewer

```yaml
subagent_type: code-quality-reviewer
```

PR の diff と worktree 内のソースコードを分析し，コード品質の観点でレビューしてください．
PR の出力形式セクションに従って Must Fix / Should Fix / Good Points で結果を出力してください．

#### Agent 2: documentation-accuracy-reviewer

```yaml
subagent_type: documentation-accuracy-reviewer
```

PR の diff と worktree 内のソースコードを分析し，ドキュメントの正確性・完全性の観点でレビューしてください．
PR の出力形式セクションに従って Must Fix / Should Fix / Good Points で結果を出力してください．

#### Agent 3: performance-reviewer

```yaml
subagent_type: performance-reviewer
```

PR の diff と worktree 内のソースコードを分析し，パフォーマンスの観点でレビューしてください．
PR の出力形式セクションに従って Must Fix / Should Fix / Good Points で結果を出力してください．

#### Agent 4: security-reviewer

```yaml
subagent_type: security-reviewer
```

PR の diff と worktree 内のソースコードを分析し，セキュリティの観点でレビューしてください．
PR の出力形式セクションに従って Must Fix / Should Fix / Good Points で結果を出力してください．

#### Agent 5: testing-reviewer

```yaml
subagent_type: testing-reviewer
```

PR の diff と worktree 内のソースコードを分析し，テストの観点でレビューしてください．
PR の出力形式セクションに従って Must Fix / Should Fix / Good Points で結果を出力してください．

### Phase 3: 結果統合 + レビューレポート生成

1. **5つの agent の結果を統合する**:
   - 各 agent の Must Fix / Should Fix / Good Points を集約する
   - 重複する指摘を統合する（同じファイル・行への指摘がある場合）

2. **Verdict の判定（2択）**:
   - Must Fix が1件以上 → `REQUEST_CHANGES`
   - Must Fix が0件 → `APPROVE`
   - **重要**: Verdict は `APPROVE` / `REQUEST_CHANGES` の2択のみ。`COMMENT` は使用しない（self review でも同様）。
     Should Fix のみが存在する場合でも `APPROVE` とする（指摘は本文に残るが、ブロックはしない）

3. **レビューレポートを生成する**:
   - 検出された言語に応じた適切なテンプレートを使用する
   - 後述の [レビューレポートテンプレート](#レビューレポートテンプレート) を参照
   - **重要**: "Must Fix" 項目には inline comment 投稿のため `` `filepath:line` `` の形式を正確に使用すること（"Should Fix" にも `` `filepath:line` `` を付けるが、inline 化はしない）
   - 各項目にはどの観点（code-quality, documentation, performance, security, testing）からの指摘かを明記すること
   - **重要**: "Must Fix" および "Should Fix" の全項目をレビューレポート本文に記載すること。「inline comments を参照」等の省略は禁止

4. **レビューレポートを表示する**:
   - 検出された言語でレビューレポートを表示する

5. **GitHub への投稿を確認する**:
   - Phase 1 で取得した既存レビュー情報に基づき，AskUserQuestion ツールでユーザーに確認する
   - **既存レビューがない場合**: 新規投稿するか／投稿しないかを確認する
   - **既存レビューがある場合**: 既存レビューの state と投稿日時を提示し，以下の選択肢を提供する:
     - 既存レビューを dismiss して新規レビューを投稿する（推奨: 既存が `REQUEST_CHANGES` で，内容が古い場合）
     - 既存レビューはそのままで新規レビューを追加する（既存レビューの指摘がまだ有効な場合）
     - 投稿しない
   - ユーザーが投稿を選択した場合:
     - dismiss を選択された場合は，既存レビューを dismiss する: `gh api -X PUT repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}/dismissals -f message="Superseded by new review"`
     - レビューレポートの "Must Fix" セクションのみから inline comments を抽出する（"Should Fix" は inline 化しない）
     - **API event の決定**:
       - 通常モード: Verdict をそのまま使う（`APPROVE` / `REQUEST_CHANGES`）
       - self review モード（PR author == 自分）: Verdict が何であれ API への `event` は `COMMENT` に変換する（GitHub仕様上の制約）。ただしレビューレポート本文の Verdict 表記は変えない
     - `gh api` を使用して reviews endpoint に投稿する（[inline comments 付きレビューの投稿](#inline-comments-付きレビューの投稿) を参照）
     - 投稿後にPRの URL を表示する
   - ユーザーが投稿しないを選択した場合:
     - そのまま Phase 4 に進む

### Phase 4: worktree のクリーンアップ

1. **worktree を必ず削除する**:
   - `git worktree remove --force <worktree-path>` で worktree を削除する
   - 残骸が残っている場合に備えて `rm -rf <worktree-path>` も実行する
   - **重要**: Phase 2 / Phase 3 で例外的に処理が中断した場合も，このクリーンアップは必ず実行する。可能であれば bash の `trap` などを使い，スクリプト終了時に確実に削除されるようにする

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

<!--　Questions or improvement suggestions, if any -->

## Verdict

<!-- APPROVE / REQUEST_CHANGES -->

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

## Suggestion(提案・質問)

<!--　質問や改善提案などがあれば記載してください -->

## Verdict(判定)

<!-- APPROVE / REQUEST_CHANGES -->

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

**"Must Fix" / "要修正" セクションのみ**から項目を抽出する。Should Fix は inline 化しない。

パターン: `` `filepath:line` - comment ``

#### ステップ 2: GitHub API 経由でレビューを投稿する

**Endpoint**: `POST /repos/{owner}/{repo}/pulls/{pull_number}/reviews`

**Request body**（通常モード）:

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

**Request body**（self review モード）:

```json
{
  "body": "Review summary...",
  "commit_id": "<latest commit SHA>",
  "event": "COMMENT",
  "comments": [...]
}
```

self review モードでは API への `event` を `COMMENT` に置換するが，body 内の Verdict 表記は元のまま（`APPROVE` または `REQUEST_CHANGES`）にすること。

`gh api` を使用してレビューを投稿する。

### セクション別コメント prefix

| セクション | 英語 Prefix     | 日本語 Prefix  |
| ---------- | --------------- | -------------- |
| Must Fix   | 🔴 **Must Fix**: | 🔴 **要修正**: |

Should Fix は inline 化しないため prefix は不要（本文記載のみ）。

### Event type

| Verdict         | 通常モードの API event | self review モードの API event |
| --------------- | ---------------------- | ------------------------------ |
| APPROVE         | `APPROVE`              | `COMMENT`                      |
| REQUEST_CHANGES | `REQUEST_CHANGES`      | `COMMENT`                      |

### 注意事項

- 行番号は新しいファイル（diff の右側）に対応するものでなければならない
- inline として投稿できないコメント（例: diff に含まれない行）は、body に含める
- 1回のレビューにつき inline comments は最大50件まで
- worktree の作成・削除に失敗した場合でも，レビュー処理自体はできる限り続行する（diff だけでもレビューは可能）が，作成失敗時はユーザーに警告を表示する
