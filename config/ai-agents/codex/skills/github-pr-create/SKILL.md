---
name: github-pr-create
description: 現在のブランチからPull Requestを作成または更新する。
---


# Pull Request 作成

## Arguments

- `language`: PRのタイトルと説明文の言語（例: "ja", "en"）。デフォルト: "English"
- `--draft`: draft PRとして作成（任意）
- `--reviewer <username>`: reviewerを指定（任意、複数指定可）
- `--label <name>`: labelを追加（任意、複数指定可）

## Context

- 現在のbranch: !`git branch --show-current`
- default branch: !`gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`
- 既存のPR: !`gh pr view --json url,state 2>/dev/null || echo "none"`
- Conventional Commits specification: !`cat ~/.dotfiles/doc/templates/conventional_commits.md`

## Task

### 0. 事前チェック

1. **default branch上での実行を防止**:
   - 現在のbranchがdefault branch（`main`, `master` 等）の場合、PRを作成せずエラーメッセージを出して中止
2. **commitの存在確認**:
   - `git log origin/<base>..HEAD` が空でないことを確認
   - commitがない場合は中止
3. **既存PRの確認**:
   - `gh pr view --json url,state` で既存のPRを確認
   - PRが既に存在する場合 → [既存PR更新フロー](#既存prの更新フロー)に進む
4. **commitの品質チェック**:
   - 以下の条件に該当するか確認:
     - `fixup!`, `squash!`, `wip`, `WIP` を含むcommitがある
     - 空のcommitメッセージがある
     - commitが多数（目安: 10個超）
   - 該当する場合、`git-squash skill` でcommitを整理するか確認:
     - ユーザーが整理を選択 → PR作成を中止し、`git-squash skill` の実行を案内
     - ユーザーが続行を選択 → そのままPR作成を続行

### 1. base branchの決定

以下の優先順位で決定する:

1. tracking branchを確認: `git rev-parse --abbrev-ref @{upstream} 2>/dev/null`
2. tracking branchが取得できない場合、repositoryのdefault branchにfallback

### 2. リモートへのpush

1. リモートbranchの存在確認: `git ls-remote --heads origin <current-branch>`
2. リモートbranchが存在しない場合:
   - `git push -u origin <current-branch>`
3. リモートbranchが存在する場合:
   - ローカルとリモートの差分を確認: `git status` および `git log origin/<current-branch>..HEAD`
   - unpushedなcommitがあれば `git push` を実行
   - divergeしている場合は `git push --force-with-lease` を提案し、ユーザーに確認してから実行

### 3. 変更内容の取得

- 差分の概要: `git diff --stat origin/<base-branch>..HEAD`
- commitの一覧: `git log --oneline origin/<base-branch>..HEAD`
- 詳細な差分: `git log -p origin/<base-branch>..HEAD`
  - **注意**: 差分が大きい場合（目安: 500行超）は `git diff --stat` の結果を中心に使い、個別ファイルの差分は必要に応じて `git diff origin/<base-branch>..HEAD -- <file>` で確認する
- **差分規模の警告**: 変更が大規模（目安: 変更ファイル20個超 or 差分500行超）の場合、PRの分割を提案する（ユーザーが続行を選べばそのまま進む）

### 4. PR templateの確認

以下のパスを順に確認し、最初に見つかったものを使用:

- `.github/pull_request_template.md`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/PULL_REQUEST_TEMPLATE/` ディレクトリ内のファイル
- `docs/pull_request_template.md`

### 5. 関連Issueの検出

1. **branch名からの抽出**: Issue番号を抽出（例: `feature/123-add-something` → `#123`）
2. **commitメッセージからの抽出**: `fix #456`, `closes #789`, `refs #101` 等のキーワードを検出
3. **存在確認**: 抽出した番号を `gh issue view <number> --json state,title` で照合（closedのIssueも含む）
4. **意味的な検索**: 自動でIssue番号が見つからない場合、PRの変更内容に基づいて `gh issue list` のタイトル・本文を分析し、関連するIssueを検索

### 6. PRタイトルと説明文の生成

#### タイトルの生成ルール

- commitの内容を要約した簡潔なタイトルを生成
- **Conventional Commits対応**: repositoryが Conventional Commits を採用している場合（直近のcommitやPRタイトルに `feat:`, `fix:` 等のprefixがある場合）、同じ規約に従う
- 1つのcommitのみの場合、そのcommitメッセージをベースにする

#### 説明文の生成ルール

- **PR templateが存在する場合**: そのtemplateのフォーマットと言語に従う（`$ARGUMENTS` の言語指定では翻訳しない）
- **PR templateが存在しない場合**: `$ARGUMENTS` で指定された言語（デフォルト: English）で[下記のデフォルトtemplate](#pull-request-template)を使用
- **関連Issueの記載**: 検出したIssueを適切なキーワードで記載
  - 解決するIssue → `Closes #xxx`
  - 参照するIssue → `Related to #xxx`

#### labelの自動提案

変更内容に基づいてlabelを提案する（repositoryに該当labelが存在する場合のみ）:

- `docs/` や `*.md` の変更 → `documentation`
- `test/` や `*_test.*`, `*.test.*` の変更 → `testing`
- 新機能の追加 → `enhancement`
- バグ修正 → `bug`

ユーザーが `--label` で明示的に指定した場合はそちらを優先する。

### 7. Pull Requestの作成

```bash
gh pr create \
  --base <base-branch> \
  --title "<PR Title>" \
  --body "<PR Description>" \
  [--draft] \
  [--reviewer <username>] \
  [--label <name>]
```

### 8. 結果の表示

以下の情報をまとめて表示する:

- 作成したPRのURL
- タイトル
- base branch → head branch
- 関連Issue（検出された場合）
- reviewer（指定された場合）
- label（指定された場合）
- 変更の概要（ファイル数、追加行数、削除行数）


## 既存PRの更新フロー

既存のPRが検出された場合:

1. 現在のPR情報を表示: `gh pr view --json title,body,url,state,labels,reviewers`
2. ユーザーに以下の選択肢を提示:
   - **タイトル・説明文を再生成して更新**: 最新のcommitに基づいてタイトル・本文を再生成し `gh pr edit` で更新
   - **pushのみ**: 新しいcommitをpushするだけでPRの内容は変更しない
   - **中止**: 何もしない
3. 更新する場合:
   - `gh pr edit <number> --title "<new title>" --body "<new body>"` で更新
   - 必要に応じて `--add-reviewer`, `--add-label` で追加
4. 更新結果を表示


## Pull Request Template

### English Template

```markdown
## Overview and Background

<!-- Describe the purpose of this PR and the background in short. -->

## Related Issues

<!-- List related Issues. Use "Closes #xxx" for Issues resolved by this PR, "Related to #xxx" for referenced Issues. -->

## Changes

<!-- Describe the changes made in this PR in bullet points. -->

## Test Instructions

<!-- Describe the test instructions for this PR. -->
```

### 日本語テンプレート

```markdown
## 概要・背景

<!-- このPRの目的と背景を簡潔に記載してください -->

## 関連Issue

<!-- 関連するIssueを記載してください。このPRで解決するIssueは「Closes #xxx」、参照するIssueは「Related to #xxx」の形式で記載 -->

## 変更内容

<!-- このPRで行われた変更を箇条書きで記載してください -->

## テスト方法

<!-- このPRのテスト方法を記載してください -->
```
