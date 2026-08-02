---
name: github-issue-resolve
description: GitHub issueを起点に「調査 → worktree作成 → 実装 → PR作成」を一気通貫で実行するSkill。実装はSubAgentに委譲し、commitとPR作成はgit-commit・github-pr-create skillに連結して実行する。「#N を解決して」「issueから実装してPRまで」のような複合依頼に使う。
allowed-tools: Task, Read, Write, Glob, Grep, Bash(gh:*), Bash(git:*), Bash(jq:*), Bash(cd:*), Skill(git-commit), Skill(github-pr-create)
---

# GitHub Issue Resolve

issue番号を起点に、調査 → 実装 → PR作成までを順に進めるSkill。
メイン会話が担うのは調査・worktree作成・SubAgentへの引き継ぎ・結果検証・クリーンアップであり、**実装(Phase 3)はSubAgentに委譲し、commitとPR作成(Phase 4)は`git-commit` skillと`github-pr-create` skillに連結する**。
SubAgent機能が使えない環境では、SubAgentの作業をメイン会話内で同じ手順で順に実施する。
Skill toolが使えない環境では、連結先skillのSKILL.mdを直接読み込み、その手順に従って実行する。

## Arguments

- `issue` (必須): 解決対象のissue番号。先頭の `#` は省略可 (例: `123` または `#123`)
- `--draft` (任意): draft PRとして作成
- `--dry-run` (任意): 指定時はPhase 1の調査と実装方針の提示で停止し、worktree作成以降 (Phase 2〜) は一切実行しない

GitHub操作は必ず`gh` CLIで行うこと。GitHub connector/pluginやMCPのGitHubツールは使用しない。

## Task

### Phase 1: 事前調査と分析

1. 以下を取得して状況を確認する:
   - リポジトリ情報: `gh repo view --json defaultBranchRef,nameWithOwner --jq '{default: .defaultBranchRef.name, repo: .nameWithOwner}'`
   - 対象issue: `gh issue view <number> --json number,title,state,body,labels,assignees,comments,url`
   - 現在のbranch: `git branch --show-current`
   - 既存worktree: `git worktree list --porcelain`
   - issueが `state: CLOSED` の場合は中止し、ユーザーに「issue #N は既にclosedです」と通知する。
2. issueのタイトルと本文から出力言語を決める。主に日本語なら日本語、それ以外または判定が曖昧な場合は英語とし、issueコメントとPR作成に使う。
3. 取得したissue本文・コメント・labelを読み、実装方針が明確か、実装に必要な情報が揃っているかを判断する:
   - 受け入れ基準・期待動作・既存コメントの合意事項を抽出する
   - コードを読めば確認できる事実は、コードベースを探索して自分で解決する
   - 仕様や方針の判断に必要な情報が欠けている場合は中止し、欠落情報をユーザーに具体的に伝えて質問する。方針を推測で補って実装に進まない。
     質問は欠落情報ごとに項目立てし、それぞれに選択肢または推奨案を添えて、回答すれば実装を再開できる形で提示する。
4. タスクキューを構築する:
   - issue本文に `- [ ]` 形式のchecklistがある場合はそれをキューとして採用する。1回のimplementer起動で完了できない項目は分割し、細かすぎる項目は統合してよい
   - checklistが無い場合、独立に検証可能な振る舞いが複数含まれるときだけ分解する。分解は、1タスクで1つの振る舞いが端から端まで完成する単位で行う。それ以外は1タスクのままとする
   - 各タスクに受け入れ基準を割り当て、依存順に並べる。キューは会話内で管理し、issueへ書き戻さない
5. 実装方針とタスク一覧は**簡潔に**ユーザーへ提示する。確認は取らず Phase 2 に進む。

### Phase 2: worktreeの作成

1. **branch名を決定する**:
   - 形式: `<type>/<issue-number>-<slug>`
     - `<type>`: issueのlabelやタイトルから推定する。Conventional Commitsで使われるものにする。 (`fix`, `feat`, `docs`, `chore`, `refactor` 等。判別不能なら `feat`)
     - `<slug>`: issueタイトルからkebab-caseで生成 (英数字とハイフンのみ、40文字以内)
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
4. **作成したworktree情報を記録する** (中止時のクリーンアップで使う):
   - branch名
   - worktreeパス
   - base branch名

### Phase 3: 実装

実装はSubAgentで行う。SubAgent同士は直接やり取りできないため、受け渡しはすべてメイン会話が構造化ブロックをパースして仲介する。プロンプトはskill内のテンプレートにタスク文脈を合成して作る。
SubAgentは毎回新規に起動し、差し戻し時も前回のSubAgentを継続しない。失敗した試行の履歴はプロンプトに含めず、`REMEDIATION` など修正に必要な情報だけを渡す (失敗履歴の持ち込みがリトライループの汚染源になるため)。

- **implementer** (`templates/implementer-prompt.md`): 1タスクの実装と検証を担い、`## Status Report` を返す
- **reviewer** (`templates/reviewer-prompt.md`): 実装を敵対的に検証し、`## Review Verdict` を返す

SubAgentのmodel選択は、環境のグローバル指示 (CLAUDE.md, AGENTS.md等) にモデル指針があればそれを最優先する。指針が無ければメイン会話と同等のモデルをデフォルトとし、定型的・機械的な作業 (typo修正、単純な置換など) に限り、implementerには、より軽量なモデルを指定してよい。reviewerにはimplementerと同等以上のモデルを使う。model指定ができない環境では指定せずに起動する。

実装を始める前に、リポジトリから正規の検証コマンドを洗い出し、`TEST_COMMANDS` / `LINT_COMMANDS` / `BUILD_COMMANDS` としてメイン会話が保持する。探索順はmanifest類 (package.json, pyproject.toml等) → タスクランナー (Makefile, justfile) → CI設定 → README。CIやpre-commitなど、リポジトリの自動化が既に使っているコマンドを優先し、見つからない種別は空でよい。

Phase 3の間は以下の制約を守る。

- ループ内で `git reset --hard` 等の破壊的リセットを行わない
- commit・push・PR作成はPhase 4まで行わない
- SubAgentの完了主張を検証の代わりにしない。判定は構造化フィールドと、reviewer・最終検証の実行結果だけで行う

#### Phase 3.1: タスクごとのイテレーション

タスクキューの順に、**1タスク = 1イテレーション**で処理する。複数タスクを1つのSubAgentにまとめて渡さない。各イテレーション完了後は「タスクID: 結果、変更ファイル数」の1行サマリだけを保持し、報告の詳細は破棄する。

1. **implementerの起動**: テンプレートに以下を合成して起動する
   - worktreeの絶対パス、base branch名と作業branch名
   - issueの番号・タイトル・本文・コメントの要約
   - 担当タスクの説明と受け入れ基準、Phase 1で決めた実装方針
   - タスクに関係する検証コマンド
   - これまでのImplementation Notes (あれば)
2. **STATUSの処理**: `## Status Report` の `- STATUS:` フィールドだけをパースする。構造化値が無い・曖昧な場合は1回だけ再要求し、構造化ブロック以外の文章から推測しない
   - `READY_FOR_REVIEW` → 3へ進む
   - `NEEDS_CONTEXT` → `MISSING` に書かれた不足情報をメイン会話が用意して1回だけ再起動する。それでも解決しなければ中止し、Phase 1と同じ形式でユーザーに質問する
   - `BLOCKED` → 中止し、`BLOCKER` と `BLOCKER_REMEDIATION` をユーザーに報告する
3. **reviewerの起動**: テンプレートに、タスク文脈・検証コマンド・implementerのStatus Report (参照用) を合成して起動する
4. **VERDICTの処理**: `## Review Verdict` の `- VERDICT:` フィールドだけをパースする。構造化値が無ければ1回だけ再要求する
   - `APPROVED` → タスク完了。次のタスクへ進む
   - `REJECTED` → `REMEDIATION` と `FINDINGS` を添えてimplementerを再起動する。同一タスクの差し戻しは**最大2周**とし、2周後もREJECTEDなら中止して未解決の指摘をユーザーに報告する
5. **知見の伝播**: タスク横断で有用な発見があれば、メイン会話がImplementation Notesとして1行で記録し、以降のimplementerのプロンプトに含める

#### Phase 3.2: 最終検証

全タスク完了後、SubAgentに検証コマンド全体の実行を依頼し、コマンド・exit code・失敗内容を報告させる。

- すべて成功 → Phase 4へ進む
- 失敗 → 失敗内容を添えてimplementerに差し戻す (最大2周)。失敗から原因タスクを特定できる場合はそのタスクの文脈を、特定できない場合は失敗した検証コマンドの修復自体をタスクとして渡す。収束しなければ中止し、結果をユーザーに報告する
- 検証コマンドが見つからなかったリポジトリではスキップし、その事実をPhase 5の結果報告に含める

### Phase 4: commitとPR作成 (git-commit / github-pr-create に連結)

メイン会話が、作業ディレクトリをworktreeの絶対パスに切り替えた上で、以下の順に連結先skillを起動する。

1. **`git-commit` skillでcommitを作成する**:
   - 対象はPhase 3でworktree内に作られたすべての変更
2. **`github-pr-create` skillでPRを作成する**:
   - Phase 1で決めた出力言語を `language` として渡し、`--draft` の指定有無を転送する
   - push・PRタイトルと本文の生成・PR作成の実行はすべて連結先skillが行う。手順をこちらで再実装しない
3. **メイン会話で結果を検証する**:
   - 作成されたPRのURLを `gh pr view <url> --json url,state` で確認する
   - PR本文に `Closes #<issue-number>` が含まれるか確認し、無ければ `gh pr edit <url> --body-file <修正した本文ファイル>` で追記する
   - PR作成に失敗した場合はworktreeをクリーンアップせず (手動修正の余地を残す)、ユーザーにエラーを伝えて中止する

### Phase 5: 結果の表示

以下を簡潔にまとめて出力する:

- **Issue**: #N タイトル / URL
- **Branch**: 作成したbranch名
- **PR**: 作成したPRのURL
- **変更概要**: ファイル数、追加/削除行数 (`git diff --stat <base>..HEAD` の結果)

### Phase 6: worktreeクリーンアップ

実装が完了した場合も、Phase 2〜5の途中でエラーまたはユーザーの中止により中断した場合も、以下のクリーンアップを行う:

1. `git worktree remove --force <worktree-path>`
2. `git branch -D <branch-name>` (ローカルbranchも削除する)
3. クリーンアップに失敗した場合はユーザーに警告する (例: worktreeは削除できたがbranchの削除に失敗した、など)
