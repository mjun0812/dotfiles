---
name: github-issue-resolve
description: GitHub issueを起点に「調査 → worktree作成 → 実装 → PR作成」を一気通貫で実行するSkill。「#N を解決して」「issueから実装してPRまで」のような複合依頼に使う。
allowed-tools: Skill, Bash(gh:*), Bash(git:*), Bash(jq:*), Bash(mkdir:*), Bash(rm:*), Bash(cd:*), Bash(ls:*), Bash(cat:*), Bash(mktemp:*), Read, Write, Edit
---

# GitHub Issue Resolve

issue番号を起点に、調査 → 実装 → PR作成までを順に進めるSkill。
**個々の作業は既存Skillへ委譲する**。
本Skillが担うのはフェーズ間の判断と引き継ぎだけであり、PR作成手順やcommit手順を独自に再実装しない。

- PR本文生成・関連Issue検出・base branch決定・push処理 → `github-pr-create`
- commitメッセージ生成・commit分割 → `git-commit`
- 既存PRの扱い → `github-pr-create`

## Arguments

- `issue` (必須): 解決対象のissue番号。先頭の `#` は省略可（例: `123` または `#123`）
- `language` (任意): issueコメント・PR本文の言語（例: `ja`, `en`）。デフォルトは `ja`。`github-pr-create` にもそのまま転送する
- `--draft` (任意): draft PRとして作成（`github-pr-create` に転送）

## Task

### Phase 1: 事前調査と分析

1. 以下を取得して状況を確認する:
   - リポジトリ情報: `gh repo view --json defaultBranchRef,nameWithOwner --jq '{default: .defaultBranchRef.name, repo: .nameWithOwner}'`
   - 対象issue: `gh issue view <number> --json number,title,state,body,labels,assignees,comments,url`
   - 現在のbranch: `git branch --show-current`
   - 既存worktree: `git worktree list --porcelain`
   - issueが `state: CLOSED` の場合は中止し、ユーザーに「issue #N は既にclosedです」と通知する。
2. 取得したissue本文・コメント・labelを読み、実装方針を決める:
   - 受け入れ基準・期待動作・既存コメントの合意事項を抽出する
   - 仕様が曖昧な場合は、コードベースを探索し、推奨の方針で判断する
   - どうしても実装不能な情報が欠けている場合のみ中止し、欠落情報を具体的に伝え、ユーザーに質問する
3. 実装方針は**簡潔に**ユーザーへ提示する。確認は取らず Phase 2 に進む。

### Phase 2: worktreeの作成

1. **branch名を決定する**:
   - 形式: `<type>/<issue-number>-<slug>`
     - `<type>`: issueのlabelやタイトルから推定（`fix`, `feat`, `docs`, `chore`, `refactor` 等。判別不能なら `feat`）
     - `<slug>`: issueタイトルからkebab-caseで生成（英数字とハイフンのみ、40文字以内）
   - 例: `feat/123-add-oauth-login`, `fix/456-handle-empty-response`
   - 既に同名のlocal branchがある場合は末尾に `-2`, `-3` を付けて衝突を避ける
2. **worktreeのパスを決定する**:
   - 形式: `<repo-root>/.tmp/<repo-name>-worktrees/<branch-name>`
   - 既存worktreeと衝突する場合は末尾に `-2`, `-3` を付けて衝突を避ける
3. **worktree作成**:
   - `git worktree add -b <branch-name> <worktree-path> <base-branch>`
   - `<base-branch>`は最新のdefault branch
   - 同じ path の worktree が存在し、未commit変更がある場合は中止する。clean な場合のみ作り直してよい。
   - 作成失敗時は中止し、エラー内容をユーザーに伝える
4. **作成したworktree情報を記録する**（中止時のクリーンアップで使う）:
   - branch名
   - worktreeパス
   - base branch名

### Phase 3: 実装

1. **作業ディレクトリをworktreeに切り替える**:
   - 以降の `git` / `gh` / ファイル操作は worktreeパス配下で実行する
   - `cd <worktree-path>` をBashで実行するか、ファイル操作の絶対パスを worktreeパス起点で組み立てる
2. **issueの内容に応じて実装する**:
   - issue本文・コメントから受け入れ基準・期待動作を抽出
   - リポジトリの既存コード規約（CLAUDE.md, AGENTS.md, README, 既存実装パターン）に従う
   - 必要なファイルを Read → Edit / Write で修正
   - **このフェーズはSkill側でロジックを規定しない**。issueの内容に応じて適切に判断する
3. **品質チェック**:
   - リポジトリにテスト・linter・formatter・型チェックの設定がある場合は実行する（例: `pytest`, `npm test`, `ruff check`, `eslint`, `tsc --noEmit`）
   - リポジトリのCLAUDE.md / AGENTS.mdに指定がある場合はそちらを優先する
   - 失敗した場合は修正してから次に進む。修正困難な場合はユーザーに相談し、ユーザー判断で Phase 4 に進むか中止するかを決める
4. **commit**:
   - `git-commit` Skillで委譲してcommitする（Conventional Commits準拠のメッセージを自動生成）
   - 複数の論理的変更がある場合は複数commitに分けるよう `git-commit` Skillに任せる

### Phase 4: PR作成（github-pr-create に委譲）

1. Skillツールで `github-pr-create` Skillを起動する
2. 受け取った引数を以下のように転送する:
   - `language`: そのまま転送
   - `--draft`: 指定されていれば転送
3. PR作成に失敗した場合はworktreeをクリーンアップせず（手動修正の余地を残す）、ユーザーにエラーを伝えて中止する

### Phase 5: 結果の表示

以下を簡潔にまとめて出力する:

- **Issue**: #N タイトル / URL
- **Branch**: 作成したbranch名
- **PR**: 作成したPRのURL
- **変更概要**: ファイル数、追加/削除行数（`git diff --stat <base>..HEAD` の結果）

### Phase 6: worktreeクリーンアップ

実装完了後とPhase 2-5の途中でエラーが出たりユーザーが中止を選んだ場合の両方で、以下のクリーンアップ処理を行う:

1. `git worktree remove --force <worktree-path>`
2. `git branch -D <branch-name>`（ローカルbranchも削除する）
3. クリーンアップに失敗した場合はユーザーに警告する（例: worktreeは削除できたがbranchの削除に失敗した、など）
