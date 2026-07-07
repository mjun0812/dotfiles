---
name: github-issue-resolve-with-subagent
description: GitHub issueを起点に「調査 → worktree作成 → 実装 → PR作成」を一気通貫で実行するSkill。実装とPR作成をSubAgentに委譲して実行する。「#N をsubagentで解決して」「実装をsubagentに任せてissueからPRまで」のような依頼に使う。
allowed-tools: Task, Read, Write, Bash(gh:*), Bash(git:*), Bash(jq:*), Bash(mkdir:*), Bash(rm:*), Bash(cd:*), Bash(ls:*), Bash(cat:*), Bash(mktemp:*)
---

# GitHub Issue Resolve with SubAgent

GitHub操作は必ず`gh` CLIで行うこと。GitHub connector/pluginやMCPのGitHubツールは使用しない。

issue番号を起点に、調査 → 実装 → PR作成までを順に進めるSkill。
メイン会話が担うのは調査・worktree作成・SubAgentへの引き継ぎ・結果検証・クリーンアップであり、**実装(Phase 3)とPR作成(Phase 4)はSubAgent(Taskツール)に委譲する**。
SubAgent機能が使えない環境では、各SubAgentの作業をメイン会話内で同じ手順で順に実施する。

## Arguments

- `issue` (必須): 解決対象のissue番号。先頭の `#` は省略可（例: `123` または `#123`）
- `language` (任意): issueコメント・PR本文の言語（例: `ja`, `en`）。デフォルトは `ja`
- `--draft` (任意): draft PRとして作成
- `--dry-run` (任意): 指定時はPhase 1の調査と実装方針の提示で停止し、worktree作成以降（Phase 2〜）は一切実行しない

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
   - `--dry-run` が指定された場合はここで停止し、Phase 2以降は実行しない。

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

### Phase 3: 実装（SubAgentに委譲）

Taskツールで実装SubAgentを1つ起動する。model はissueの性質で選ぶ: 定型的な実装なら `sonnet`、設計判断や複数ファイル横断の変更を伴うなら `opus`（迷ったら `opus`。model 指定ができない環境ではそのまま起動する）。

1. **SubAgentに以下の情報をpromptで渡す**:
   - worktreeの絶対パス。**すべてのファイル操作・コマンド実行をこのパス配下で行う**こと
   - issueの番号・タイトル・本文・コメントの要約（受け入れ基準・期待動作を含む）
   - Phase 1で決めた実装方針
   - base branch名と作業branch名
2. **SubAgentへの作業指示**（promptに含める）:
   - リポジトリの既存コード規約（CLAUDE.md, AGENTS.md, README, 既存実装パターン）に従って実装する
   - リポジトリにテスト・linter・formatter・型チェックの設定がある場合は実行する。CLAUDE.md / AGENTS.mdに指定がある場合はそちらを優先する。失敗した場合は修正してから次に進む
   - 実装が完了したらcommitする。commitメッセージはConventional Commits形式（2行目は空行、説明は3行目から）で、何を・なぜ変更したかを具体的に書く。複数の論理的変更がある場合はcommitを分ける
   - push・PR作成は行わない
   - 完了報告として「変更ファイル一覧・commit一覧・品質チェックの実行結果・修正できなかった問題」を返す
3. **メイン会話で結果を検証する**:
   - `git -C <worktree-path> log --oneline <base-branch>..HEAD` でcommitが存在することを確認する
   - `git -C <worktree-path> status --porcelain` で未commit変更が残っていないことを確認する。残っている場合はSubAgentの報告と突き合わせ、必要ならcommitの追加をSubAgentに依頼する
   - commitが1つもない、またはSubAgentが実装不能と報告した場合は、理由をユーザーに伝えて中止する（Phase 6のクリーンアップを実行）
   - 品質チェックの失敗が未解決のまま報告された場合はユーザーに相談し、ユーザー判断で Phase 4 に進むか中止するかを決める

### Phase 4: PR作成（SubAgentに委譲）

Taskツールで PR作成SubAgent を起動する（model: `sonnet`。model 指定ができない環境ではそのまま起動する）。

1. **SubAgentに以下の情報をpromptで渡す**:
   - worktreeの絶対パス（すべての `git` / `gh` 操作をこのパス配下で実行する）
   - 作業branch名とbase branch名
   - issue番号（PR本文に `Closes #N` を含めるため）
   - `language`（PRタイトル・本文の言語）
   - `--draft` の指定有無
2. **SubAgentへの作業指示**（promptに含める）:
   - `git push -u origin <branch-name>` でpushする
   - `git diff --stat origin/<base-branch>..HEAD` と `git log origin/<base-branch>..HEAD` で変更内容を把握する
   - PRタイトルはConventional Commits形式で、変更内容を要約して生成する
   - PR本文は、repositoryのPR template（`.github/pull_request_template.md` 等）があればそれに従い、なければ「目的・背景・主な変更点・テスト方法」の構成で生成する。コードを参照しなくても内容が理解できるように書き、`Closes #<issue-number>` を含める。テスト方法は実行したコマンドと結果をコピペ可能な形式で記載する
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
