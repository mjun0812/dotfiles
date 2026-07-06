---
name: github-issue-create
description: >-
  ユーザーから情報を収集してGitHub Issueを作成するSkill。
  ユーザーが「issue作って」「バグ報告を起票して」のように依頼したら使うこと。
  複数候補の一括起票はgithub-issue-discover、issue解決からPR作成まではgithub-issue-resolveを使う。
allowed-tools: Bash(gh:*), Bash(git:*), Bash(ls:*), Bash(cat:*), Bash(bat:*), Read
---

# Create GitHub Issue

GitHub操作は必ず`gh` CLIで行うこと。GitHub connector/pluginやMCPのGitHubツールは使用しない。

ユーザーから自由入力で受け取ったIssue概要を元に、種別とラベルを自動判定してGitHub Issueを作成する。

## Arguments

- `language`: Issueのタイトルと本文の言語（例: "ja", "en"）。デフォルト: "en"
- `--label <name>`: ラベルを **追加** する（任意、複数指定可）。自動判定されたラベルに加えて付与される
- `--assignee <username>`: 担当者を割り当て（任意、複数指定可）
- `--dry-run`: Issueを作成せず、生成したタイトル・本文・ラベル・担当者の提示のみ行う

## Issue Templates

テンプレートは以下の優先順位で選択する：

1. **リポジトリ内テンプレート**: `.github/ISSUE_TEMPLATE/` が存在する場合はそれを使用
2. **Skill 同梱テンプレート（フォールバック）**: リポジトリにテンプレートがない場合は本skillの `references/` 配下を使用
   - 英語（`language` が "en" または未指定）: `references/ISSUE_TEMPLATE/`
   - 日本語（`language` が "ja"）: `references/ISSUE_TEMPLATE_JA/`

各ディレクトリには以下のテンプレートが含まれる：

- `feature_request.md` - 機能追加（デフォルトラベル: `enhancement`）
- `bug_report.md` - バグ報告（デフォルトラベル: `bug`）
- `task.md` - タスク（デフォルトラベルなし）
- `test.md` - テスト追加（デフォルトラベル: `test`）

## Task

1. **前提情報の取得**: 以下を取得する。
   - リポジトリ情報: `gh repo view --json name,owner --jq '.owner.login + "/" + .name'`
   - 利用可能なラベル一覧: `gh label list --limit 100 --json name,description --jq '.[] | "\(.name)\t\(.description // "")"'`
   - リポジトリ内Issueテンプレートの有無: `ls .github/ISSUE_TEMPLATE/ 2>/dev/null || echo "none"`
   - `gh auth status` が失敗した場合は作業を停止し、認証を案内する

2. **下書き素材の確保**: ユーザーの依頼にIssueの内容（何をしたいか・何が起きているか）が含まれていれば、そのテキスト全体を「下書き素材」として使い、追加の入力は求めない。依頼に内容がまったく含まれていない場合のみ、AskUserQuestion ではなく **自由テキスト入力** で概要を受け取る:

   > 作成したいIssueの内容を自由に記述してください。背景、目的、再現手順、完了条件など分かる範囲で構いません。1行でも構いません。

3. **種別の自動判定**: 下書き素材の内容からテンプレートを自動選択する。判定ヒューリスティック:
   - 「バグ」「不具合」「壊れている」「動かない」「再現」「エラー」「bug」「broken」「reproduce」「stack trace」などが含まれる → `bug_report`
   - 「テストがない」「カバレッジ」「テスト追加」「test missing」「add test」「coverage」などが含まれる → `test`
   - 「機能追加」「新機能」「〜したい」「実装したい」「提案」「improve」「feature」「proposal」などが含まれる → `feature_request`
   - 上記のいずれにも当てはまらない雑多な作業（リファクタ、調査、ドキュメント整備など）→ `task`

   判定が曖昧な場合は `task` を選ぶ（最も汎用的）。判定結果はステップ9の報告時にユーザーに開示する。

4. **テンプレートの読み込み**: ステップ1で確認したテンプレート所在に従い、ステップ3で選んだテンプレート種別のファイルを Read で読み込む。フロントマターから `labels` をデフォルトラベルとして抽出し、本文部分は構造の参考にする。

5. **タイトルと本文の生成**: 下書き素材を元に、テンプレートに沿った形でタイトルと本文を生成する:
   - **タイトル**: 下書き素材の要点を1行で要約。先頭に種別を示す接頭辞は付けない（ラベルで判別可能なため）
   - **本文**: 選択したテンプレートのセクション見出しを利用し、下書き素材からの情報を該当セクションに振り分ける
     - **Feature Request**: 背景→「Background & Summary / 背景・概要」、要件→「Specifications & Requirements / 仕様・要件」、完了条件→「Acceptance Criteria / 完了条件」
     - **Bug Report**: 現象→「Summary / 概要」、正常動作→「Expected Behavior / 期待される動作」、再現手順→「Steps to Reproduce / 再現手順」、ログ/コード→該当セクション
     - **Task**: 背景・目的→「Background, Purpose & Summary / 背景・目的・概要」、完了条件→「Acceptance Criteria / 完了条件」
     - **Test**: 対象・目的→「Summary & Purpose / 概要・目的」、テストケース→「Test Scenarios to Implement / 実装するテストのシナリオ」、完了条件→「Acceptance Criteria / 完了条件」
   - 下書き素材から情報が不足しているセクションは、コメントプレースホルダーを残すのではなく **セクション自体を省略** する
   - 最終的なIssue本文からはフロントマターを除去する

6. **ラベルの自動判定**: 付与するラベルを次の手順で決める:
   - **デフォルトラベル**: ステップ4でテンプレートのフロントマターから抽出したラベル（例: `enhancement` / `bug` / `test`）を起点とする
   - **追加ラベルの推定**: ステップ1で取得した「リポジトリの既存ラベル一覧」とその description を参照し、下書き素材の内容に合致するラベルを選ぶ。例:
     - 下書きに「ドキュメント」「README」「docstring」などが含まれ、既存ラベルに `documentation` がある → 追加
     - 「セキュリティ」「脆弱性」「XSS」「SQLi」などが含まれ、既存ラベルに `security` がある → 追加
     - 「CI」「GitHub Actions」「workflow」が含まれ、既存ラベルに `ci` がある → 追加
     - 「パフォーマンス」「遅い」「最適化」が含まれ、既存ラベルに `performance` がある → 追加
   - **存在しないラベルは付与しない**: 推定したラベル名がリポジトリの既存ラベル一覧に存在しない場合はスキップする
   - **ユーザー指定の追加**: 引数 `--label` で渡されたラベルを最終リストに追加する
   - 最終的なラベルリストは重複排除する

7. **作成可否の判断**: 生成したタイトル・本文について、ユーザーへの確認は行わない。次の場合のみ例外とする:
   - **情報不足**: 下書き素材が乏しく、タイトルすら意味のある形で生成できない場合は、不足している点をユーザーに質問し、回答を反映してからステップ3以降をやり直す
   - **dry-run**: `--dry-run` が指定されている場合は、生成したタイトル・本文・種別・ラベル・担当者を提示して終了する（Issueは作成しない）

8. **Issueの作成**:

   ```
   gh issue create --title "<title>" --body "<body>" [--label <name> ...] [--assignee <username> ...]
   ```

9. **結果の報告**:
   - 作成されたIssueのURLを表示
   - 概要（タイトル、選択されたテンプレート種別、付与されたラベル、担当者）を表示
