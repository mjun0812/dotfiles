---
name: github-pr-create
description: Pull Requestを作成するSkill。現在のbranchからpull requestを作成する。言語指定可能。
allowed-tools: Read, Write, Task, Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*), Bash(mktemp:*)
---

# Pull Request 作成

このSkillは、現在のbranchからpull requestを作成するためのものです。PRのタイトルと説明文は、変更内容に基づいて自動生成されます。PRの説明文は、コードを参照しなくてもPRの内容が理解できるように、変更の目的、背景、内容をわかりやすく説明します。また、テスト方法や検証方法も具体的に記述し、コピペ可能なコマンドや手順を提供します。

## Arguments

- `language`: PRのタイトルと説明文の言語（例: "ja", "en"）。デフォルト: "English"
- `--draft`: draft PRとして作成（Optional）
- `--reviewer <username>`: reviewerを指定（Optional、複数指定可）
- `--label <name>`: labelを追加（Optional、複数指定可）

## 0. 事前チェック

1. **default branch上での実行を防止**:
   - 現在のbranchがdefault branch（`main`, `master` 等）の場合、PRを作成せずエラーメッセージを出して中止
2. **commitの存在確認**:
   - `git log origin/<base>..HEAD` が空でないことを確認
   - 未commitの変更は無視してcommit済みの変更のみを対象とする
   - commitがない場合は中止
3. **既存PRの確認**:
   - `gh pr view --json url,state` で既存のPRを確認
   - PRが既に存在する場合は、そのURLと状態を表示して中止
4. **base branchの決定**:
   - tracking branchを確認: `git rev-parse --abbrev-ref @{upstream} 2>/dev/null`
   - tracking branchが取得できない場合、repositoryのdefault branchにfallback
5. **base branchの最新化**:
   - 比較基準を最新化するため、base branch決定後に `git fetch origin <base-branch>` を実行する
   - 以降のcommit確認と差分取得では、最新化した `origin/<base-branch>` を基準にする
6. **PR templateの確認**:
   - 以下のパスを順に確認し、最初に見つかったものを使用:
     - `.github/pull_request_template.md`
     - `.github/PULL_REQUEST_TEMPLATE.md`
     - `.github/PULL_REQUEST_TEMPLATE/` ディレクトリ内のファイル
     - `docs/pull_request_template.md`
   - repositoryにPR templateが存在しない場合、指定言語に応じて以下を使用:
     - English: [`references/pr_template.md`](references/pr_template.md)
     - Japanese: [`references/pr_template_ja.md`](references/pr_template_ja.md)
7. Conventional Commits規約 [`references/conventional_commits.md`](references/conventional_commits.md)

## 1. リモートへのpush

- `git push` または `git push -u origin <current-branch>` で現在のbranchをpushする
- 通常のpushが失敗し、履歴書き換えが必要な場合のみ、ユーザーに確認して `git push --force-with-lease` を実行する

## 2. 変更内容の取得

- 差分の概要: `git diff --stat origin/<base-branch>..HEAD`
- commitの一覧: `git log --oneline origin/<base-branch>..HEAD`
- 詳細な差分: `git log -p origin/<base-branch>..HEAD`
- **注意**: 差分が大きい場合（目安: 500行超）は `git diff --stat` の結果を中心に使い、個別ファイルの差分は必要に応じて `git diff origin/<base-branch>..HEAD -- <file>` で確認する

## 3. PRタイトル、関連Issue、Labelの生成

PRタイトル、関連Issue、label候補はSubAgentに委譲して並列に作成する。
3つのSubAgentは候補と根拠だけを返し、最終的な統合・判断・PR本文の生成はメイン会話側で行う。
SubAgentにはPR作成、PR本文ファイルの書き出し、`gh pr create` の実行を行わせない。
SubAgentはあくまでPRタイトル、関連Issue、labelの候補を生成する役割に限定し、PRの作成に必要な情報を提供することに専念する。
最終的にPRタイトル、関連Issue、labelの最終決定はメイン会話側で行い、次のステップでPR本文の生成とPRの作成を行う。

### SubAgent1: タイトル候補の生成

- commitとブランチの差分の内容を要約した簡潔なタイトル候補を生成する
- PRのタイトルはConventional Commits規約に従った候補を生成する
- 1つのcommitのみの場合、そのcommitメッセージをベースにした候補を生成する

### SubAgent2: 関連Issueの検出

- branch名からIssue番号を抽出する（例: `feature/123-add-something` → `#123`）
- commitメッセージから `fix #456`, `closes #789`, `refs #101` 等のキーワードを検出する
- PRの変更内容に基づいて `gh issue list` のタイトル・本文を分析し、関連するIssue候補を検索する

### SubAgent3: labelの自動提案

- リポジトリのlabelを取得し、その中から候補を選定する: `gh label list --json name`
- 変更内容に基づくlabel候補を提案する
- ユーザーが `--label` で明示的に指定した場合はそのlabelを必ず使用する

## 4. 説明文の生成

- **PR template**: 事前チェックで選択したtemplateのフォーマットと言語に従う（repositoryのtemplateは指定言語では翻訳しない）
- `2. 変更内容の取得` で取得した差分概要、commit一覧、詳細差分を根拠にして本文を生成する
- コードを参照しなくてもPRの内容が理解できるよう、変更の目的、背景、主な変更点、影響範囲をわかりやすく説明する
- 関連Issue候補がある場合は、解決するIssueには `Closes #xxx`、参照のみのIssueには `Related to #xxx` を使う
- テスト方法や検証方法は具体的に記述し、実行したコマンドと結果をコピペ可能な形式で記載する
- テストを実行していない場合は、未実行であることと理由を明記する

## 5. Pull Requestの作成

1. 生成したPR説明文は、先にMarkdownファイルへ書き出す:
   - 例: `/tmp/YYYYMMDD-HHMMSS-pr-body.md`
   - `--body "<PR Description>"` のように本文を直接コマンド引数へ埋め込むことは禁止
   - 複数行本文、Markdown、引用符、バッククォート、絵文字を安全に渡すため、必ず `--body-file` を使う
2. PRを作成する:
   `--assignee @me` を**必ず**付与し、PRの担当者を自分（PR作成者）に設定する

   ```bash
   gh pr create \
     --base <base-branch> \
     --title "<PR Title>" \
     --body-file /tmp/YYYYMMDD-HHMMSS-pr-body.md \
     --assignee @me \
     [--draft] \
     [--reviewer <username>] \
     [--label <name>]
   ```

## 6. 結果の表示

以下の情報をまとめて表示する:

- 作成したPRのURL
- タイトル
- base branch → head branch
- 関連Issue（検出された場合）
- assignee（`@me`）
- reviewer（指定された場合）
- label（指定された場合）
- 変更の概要（ファイル数、追加行数、削除行数）
