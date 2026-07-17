---
name: github-issue-resolve-with-subagent
description: GitHub issueを起点に「調査 → worktree作成 → 実装 → PR作成」を一気通貫で実行するSkill。実装とPR作成をSubAgentに委譲して実行する。「#N をsubagentで解決して」「実装をsubagentに任せてissueからPRまで」のような依頼に使う。
allowed-tools: Task, Read, Write, Bash(gh:*), Bash(git:*), Bash(jq:*)
---

# GitHub Issue Resolve with SubAgent

issue番号を起点に、調査 → 実装 → PR作成までを順に進めるSkill。
メイン会話が担うのは調査・worktree作成・SubAgentへの引き継ぎ・結果検証・クリーンアップであり、**実装(Phase 3)とPR作成(Phase 4)はSubAgent(Taskツール)に委譲する**。
SubAgent機能が使えない環境では、各SubAgentの作業をメイン会話内で同じ手順で順に実施する。

## Arguments

- `issue` (必須): 解決対象のissue番号。先頭の `#` は省略可（例: `123` または `#123`）
- `language` (任意): issueコメント・PR本文の言語（例: `ja`, `en`）。デフォルトは `ja`
- `--draft` (任意): draft PRとして作成
- `--dry-run` (任意): 指定時はPhase 1の調査と実装方針の提示で停止し、worktree作成以降（Phase 2〜）は一切実行しない

GitHub操作は必ず`gh` CLIで行うこと。GitHub connector/pluginやMCPのGitHubツールは使用しない。

## Task

### Phase 1: 事前調査と分析

1. 以下を取得して状況を確認する:
   - リポジトリ情報: `gh repo view --json defaultBranchRef,nameWithOwner --jq '{default: .defaultBranchRef.name, repo: .nameWithOwner}'`
   - 対象issue: `gh issue view <number> --json number,title,state,body,labels,assignees,comments,url`
   - 現在のbranch: `git branch --show-current`
   - 既存worktree: `git worktree list --porcelain`
   - issueが `state: CLOSED` の場合は中止し、ユーザーに「issue #N は既にclosedです」と通知する。
2. 取得したissue本文・コメント・labelを読み、実装方針が明確か、実装に必要な情報が揃っているかを判断する:
   - 受け入れ基準・期待動作・既存コメントの合意事項を抽出する
   - 仕様が曖昧な場合は、コードベースを探索し、推奨の方針で判断する
   - どうしても実装不能な情報が欠けている場合のみ中止し、欠落情報をユーザーに具体的に伝えて質問する。
     質問は欠落情報ごとに項目立てし、それぞれに選択肢または推奨案を添えて、回答すれば実装を再開できる形で提示する。
3. 実装方針は**簡潔に**ユーザーへ提示する。確認は取らず Phase 2 に進む。

### Phase 2: worktreeの作成

1. **branch名を決定する**:
   - 形式: `<type>/<issue-number>-<slug>`
     - `<type>`: issueのlabelやタイトルから推定する。Conventional Commitsで使われるものにする。（`fix`, `feat`, `docs`, `chore`, `refactor` 等。判別不能なら `feat`）
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

実装には以下のSubAgentを使用する。SubAgent同士は直接やり取りできないため、検証結果の受け取りと修正依頼はすべてメイン会話が仲介する。
modelはメイン会話と同等のモデルをデフォルトとする。定型的・機械的な作業 (typo修正、単純な置換など) に限り、Implementation SubAgentにより軽量なモデルを指定してよい。Review SubAgentとDebug SubAgentは常にメイン会話と同等のモデルを使う。model指定ができない環境では指定せずに起動する。

- **Implementation SubAgent**: 実装を行うSubAgent。実装に行き詰まった場合はメイン会話に相談し、必要に応じてSubAgentを再起動する。
- **Review SubAgent**: Implementation SubAgentが実装した変更を敵対的にコードレビューし、問題点をメイン会話に返すSubAgent。
- **Debug SubAgent**: テスト・linter・formatter・型チェックを実行し、さらに実装結果を実際に動かして期待動作を満たすか確認し、結果をメイン会話に返すSubAgent。

1. **Implementation SubAgentへの作業指示**:
   - worktreeの絶対パス。**すべてのファイル操作・コマンド実行をこのパス配下で行う**こと
   - issueの番号・タイトル・本文・コメントの要約・base branch名と作業branch名
   - Phase 1で決めた実装方針
   - 受け入れ基準・期待動作
   - リポジトリの既存コード規約（CLAUDE.md, AGENTS.md, README, 既存実装パターン）に従って実装する
   - commit, push, PR作成は行わない
   - 完了報告として「変更ファイル一覧・修正できなかった問題」を返す
2. **Review SubAgentとDebug SubAgentによる実装の検証**: 両者を並列に起動し、Implementation SubAgentが返した変更ファイル一覧とworktreeパスを渡して、それぞれの役割の検証を行わせる
3. **メイン会話で結果を検証する**:
   - Review SubAgentとDebug SubAgentの結果を受け取り、問題がなければ「実装完了」としてPhase 4に進む。
   - 問題があればImplementation SubAgentに修正を依頼し、再度Review SubAgentとDebug SubAgentで検証する。両SubAgentの指摘がなくなるまで、実装と検証を繰り返す。

### Phase 4: PR作成

PRの作成をSubAgentに委譲する。SubAgentはPhase 3で作成された変更をcommit・pushし、PRタイトル・本文を生成してPRを作成する。
SubAgentはPR作成後、PRのURL・タイトル・base/head branchを返す。

1. **SubAgentに以下の情報をpromptで渡す**:
   - worktreeの絶対パス（すべての `git` / `gh` 操作をこのパス配下で実行する）
   - 作業branch名とbase branch名
   - issue番号（PR本文に `Closes #N` を含めるため）
   - `language`（PRタイトル・本文の言語）
   - `--draft` の指定有無
2. **SubAgentへの作業指示**（promptに含める）:
   - `git status` と `git diff` で変更内容を把握し、worktree内の変更をすべてstageしてcommitを作成する。commitメッセージはConventional Commits形式で、変更内容を具体的に要約する
   - `git push -u origin <branch-name>` でpushする
   - `git diff --stat origin/<base-branch>..HEAD` と `git log origin/<base-branch>..HEAD` で変更内容を把握する
   - PRタイトルはConventional Commits形式で、変更内容を要約して生成する
   - PR本文は、repositoryのPR template（`.github/pull_request_template.md` 等）があればそれに従い、なければ「目的・背景・主な変更点・テスト方法」の構成で生成する。コードを参照しなくても内容が理解できるように書き、`Closes #<issue-number>` を含める。テスト方法は実行したコマンドと結果をコピペ可能な形式で記載する。ただしCIで自動実行されるlint・format・型チェックは記載せず（そのチェック設定自体を変更した場合を除く）、CIが検証しない動作確認の手順と結果を書く
   - PR本文は一時ファイルへ書き出し、`--body-file` で渡す。`--body` への直接埋め込みは禁止
   - `gh pr create --base <base-branch> --title "<title>" --body-file <file> --assignee @me` で作成する（`--draft` 指定時は付与する）
   - 完了報告として「PRのURL・タイトル・base/head branch」を返す
3. **メイン会話で結果を検証する**:
   - 返されたPR URLを `gh pr view <url> --json url,state` で確認する
   - PR作成に失敗した場合はworktreeをクリーンアップせず（手動修正の余地を残す）、ユーザーにエラーを伝えて中止する

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
