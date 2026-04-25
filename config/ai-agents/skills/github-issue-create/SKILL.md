---
name: github-issue-create
description: ユーザーから情報を収集してGitHub Issueを作成するSkill。
allowed-tools: Bash(gh:*), Bash(git:*), Bash(ls:*), Bash(cat:*), Bash(bat:*), Read
---

# Create GitHub Issue

ユーザーから情報を収集して、インタラクティブにGitHub Issueを作成する。

## Arguments

- `language`: Issueのタイトルと本文の言語（例: "ja", "en"）。デフォルト: "en"
- `--label <name>`: ラベルを追加（任意、複数指定可）
- `--assignee <username>`: 担当者を割り当て（任意、複数指定可）

## Context

以下を取得してから作業を開始してください。

- リポジトリ情報: `gh repo view --json name,owner --jq '.owner.login + "/" + .name'`
- 利用可能なラベル: `gh label list --limit 50 --json name --jq '.[].name' 2>/dev/null || echo "none"`
- リポジトリ内Issueテンプレート: `ls .github/ISSUE_TEMPLATE/ 2>/dev/null || echo "none"`

## Issue Templates

テンプレートは以下の優先順位で選択する：

1. **リポジトリ内テンプレート**: `.github/ISSUE_TEMPLATE/` が存在する場合はそれを使用
2. **フォールバックテンプレート**: リポジトリにテンプレートがない場合は `doc/templates/` 配下を使用
   - 英語（en）: `doc/templates/ISSUE_TEMPLATE/`
   - 日本語（ja）: `doc/templates/ISSUE_TEMPLATE_JA/`

各ディレクトリには以下のテンプレートが含まれる：

- `feature_request.md` - 機能追加
- `bug_report.md` - バグ報告
- `task.md` - タスク
- `test.md` - テスト追加

## Task

1. **Issue種別の確認**: AskUserQuestion を使用して、作成するIssueの種類を確認する。各選択肢の description にはテンプレートの `about` フィールドの内容を使用する：
   - ✨ 機能追加 (Feature Request) — Propose a new feature or improvement
   - 🐛 バグ報告 (Bug Report) — Report a bug or issue
   - 📝 タスク (Task) — Work that doesn't fit the above categories
   - 🧪 テスト追加 (Add Tests) — Add or improve tests

2. **テンプレートの読み込み**: 以下の優先順位でテンプレートを決定する：
   - **優先度1**: リポジトリ内に `.github/ISSUE_TEMPLATE/` が存在する場合、該当するテンプレートを読み込む
   - **優先度2（フォールバック）**: リポジトリにテンプレートがない場合：
     - 英語（`language` が "en" または未指定）: `doc/templates/ISSUE_TEMPLATE/` から読み込む
     - 日本語（`language` が "ja"）: `doc/templates/ISSUE_TEMPLATE_JA/` から読み込む

3. **情報の収集**: AskUserQuestion を使用して、ユーザーにIssueの概要を自由入力で記述してもらう：
   - 「どのようなIssueを作成しますか？自由に記述してください」と質問する
   - ユーザーは背景、目的、詳細などを自由に記述できる

4. **タイトルと本文の提案**: ユーザーの入力を元に、テンプレートに沿った形でタイトルと本文を生成し、ユーザーに提示する：
   - テンプレートのフロントマターから以下を抽出する：
     - `labels`: デフォルトラベルとして使用（例: `labels: enhancement`, `labels: bug`, `labels: test`）
     - `about`: Issue種別の補足説明として活用
   - ユーザーの入力内容を、テンプレート種別に応じて以下のセクションに振り分ける：
     - **Feature Request**: 背景→「Background & Summary」、具体的な要件→「Specifications & Requirements」、完了基準→「Acceptance Criteria」
     - **Bug Report**: 現象→「Summary」、正常動作→「Expected Behavior」、手順→「Steps to Reproduce」、コード/ログ→該当セクション
     - **Task**: 背景と目的→「Background, Purpose & Summary」、完了基準→「Acceptance Criteria」
     - **Test**: 対象と目的→「Summary & Purpose」、完了基準→「Acceptance Criteria」、テストケース→「Test Scenarios to Implement」
   - ユーザー入力から情報が不足しているセクションは、コメントプレースホルダーを残すのではなくセクション自体を省略する
   - 生成したタイトルと本文をユーザーに提示し、確認または修正を求める
   - 最終的なIssue本文からはフロントマターを除去する

5. **確認と修正**: ユーザーが提案内容を確認し、必要に応じて修正を依頼できるようにする

6. **Issueの作成**:
   ```
   gh issue create --title "<title>" --body "<body>" [--label <name>] [--assignee <username>]
   ```
   - テンプレートのフロントマターに含まれるラベルをデフォルトとして使用
   - `--label` がユーザーから指定された場合は、追加でそのラベルを付与
   - `--assignee` がユーザーから指定された場合は、その担当者を割り当て

7. **結果の報告**:
   - 作成されたIssueのURLを表示
   - 概要（タイトル、ラベル、担当者）を表示
