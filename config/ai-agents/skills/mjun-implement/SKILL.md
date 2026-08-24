---
name: mjun-implement
description: >-
  spec (`.mjun/specs/` のLocal spec、GitHub Issue番号、または単発の設計doc) を起点に「内容検査 → worktree作成 → task単位の実装 → Acceptance Criteria照合 → commit → 必要ならPR作成」を一気通貫で実行するSkill。
  正本は常にLocal specで、Issue番号は取り込み済みspecへの逆引き (未取り込みなら自動取込み) として扱う。
  実装はSubAgentに委譲し、commitとPR作成はgit-commit・github-pr-create skillに連結する。
  ユーザーが「#Nを実装して」「このspecを実装して」「実装してPRまで」のように依頼したら使うこと。
  specの作成・磨き上げには使わない。
allowed-tools: Task, Read, Write, Edit, Glob, Grep, Bash(gh:*), Bash(git:*), Bash(jq:*), Bash(cd:*), Bash(cat:*), Bash(ls:*), AskUserQuestion, Skill(git-commit), Skill(github-pr-create)
---

# mjun-implement

specを起点に、内容検査 → 実装 → commit → (必要なら) PR作成までを進めるSkillです。
メイン会話が担うのは検査・worktree作成・SubAgentへの引き継ぎ・進捗の永続化・結果検証・クリーンアップであり、**実装 (Phase 3) はSubAgentに委譲し、commitとPR作成 (Phase 4) は `git-commit` skillと `github-pr-create` skillに連結する**。
SubAgent機能が使えない環境では、SubAgentの作業をメイン会話内で同じ手順で順に実施する。Skill toolが使えない環境では、連結先skillのSKILL.mdを直接読み込み、その手順に従って実行する。

GitHub操作は必ず `gh` CLIで行うこと。GitHub connector/pluginやMCPのGitHubツールは使用しない。

## Arguments

- `source` (必須): 実装対象。GitHub Issue番号 (`#123` / `123`)、`.mjun/specs/<slug>` のLocal specディレクトリ、または単発Markdownのパス
- `--pr` / `--no-pr` (任意): 実装をPRとして届けるか、local commitまでで終えるか。**どちらも未指定の場合は、worktree作成前に確認する** (長時間の自律実装の最後で確認待ちにしない)
- `--draft` (任意): `--pr` 時にdraft PRとして作成
- `--dry-run` (任意): Phase 1の検査・taskキュー・実装方針の提示で停止し、worktree作成以降 (Phase 2〜) は一切実行しない

### source種別

1. `.mjun/specs/<slug>` のディレクトリ → **spec mode**。配下の `spec.md` (必須)・`decisions.md`・`design.md`・`tasks.md` をReadする
2. Issue番号またはGitHub URL → `.mjun/specs/*/spec.md` の `Source: #<number>` を検索してLocal specを逆引きし、spec modeとして扱う。見つからなければ**自動取込み**を行う: `gh issue view <number> --json number,title,state,body,labels,comments,url` で取得し (`state: CLOSED` なら中止して報告)、本文とコメントを機械的に `.mjun/specs/<slug>/spec.md` へ構造化して `Source: #<number>` を記録する (磨き・grill・調査はしない)。取り込んだspecで続行してよいかはPhase 1の内容検査が判定する
3. その他のMarkdownパス → **doc mode**。ファイル全文を起点とする (frontmatterがあれば除く)

**Local specの参照・更新は、常にメインrepositoryの絶対パスで行う。** `.mjun/` はgit管理外のためworktreeやPR checkoutには存在しない。SubAgentへはspecの内容をプロンプトに合成して渡し、worktree内の `.mjun/` パスを読ませない。

## Task

### Phase 1: 内容検査とtaskキュー構築

1. 以下を取得して状況を確認する:
   - リポジトリ情報: `gh repo view --json defaultBranchRef,nameWithOwner` (Local spec / doc modeでghが失敗する場合は `git symbolic-ref --short refs/remotes/origin/HEAD`、それも失敗したら現在のbranch)
   - source本文 (source種別に従う)
   - 現在のbranch: `git branch --show-current`、既存worktree: `git worktree list --porcelain`
2. 出力言語をsourceの言語から決める (主に日本語なら日本語、それ以外または曖昧なら英語)。コメント・commit・PR作成に使う
3. **内容検査** (全source共通。承認状態の目印は存在しないため、内容だけで判定する):
   1. **情報の充足**: Goal・受け入れ基準・実装方針など、実装に必要な情報が揃っているか。コードを読めば確認できる事実は自分で解決する。仕様や方針の判断に必要な情報が欠けている場合は中止し、欠落情報を項目立てて具体的に伝え、`mjun-specify` でspecを詰めることを案内する。方針を推測で補って実装に進まない
   2. **要確認の残留**: decision log (`decisions.md`、または取り込んだspec本文の要確認記載) に `tentative` (要確認) の暫定決定が残っていないか。残っていれば一覧を提示し、このまま進めてよいかをユーザーに確認する
4. **taskキューを構築する**:
   - specに `tasks.md` がある場合は、それをキューとして採用する。`Status: done` のtaskは**完了扱いでスキップする** (中断後のresume)
   - 無い場合は、独立に検証可能な振る舞いが複数含まれるときだけ、1タスク1振る舞いのvertical sliceへ分解する。それ以外はspec全体を1タスクとして扱う
   - 各タスクの受け入れ基準とBoundary (specにBoundariesがある場合) を確認し、依存順 (Blocked by) に並べる
5. `--pr` / `--no-pr` が未指定なら、ここでAskUserQuestionにより配送方法を確認する (使えない環境では選択肢をテキストで提示する)
6. 実装方針とタスク一覧を**簡潔に**提示する。`--dry-run` はここで終了する。それ以外は確認を取らずPhase 2へ進む

### Phase 2: worktreeの作成

1. **branch名を決定する**: 形式は `<type>/<slug>` (specが `Source: #N` を持つ場合は `<type>/<N>-<slug>`)。`<type>` はConventional Commitsの種別 (`fix`, `feat`, `docs`, `chore`, `refactor` 等。判別不能なら `feat`)、`<slug>` はタイトルからkebab-case (英数字とハイフン、40文字以内)。既存branchと衝突する場合は末尾に `-2`, `-3` を付ける
2. **worktreeのパス**: `<repo-root>/.tmp/<repo-name>-worktrees/<branch-name>`。既存と衝突する場合は末尾に `-2`, `-3` を付ける
3. `git worktree add -b <branch-name> <worktree-path> <base-branch>` (`<base-branch>` は最新のdefault branch)。同じpathのworktreeに未commit変更がある場合は中止する。作成失敗時は中止してエラーを伝える
4. branch名・worktreeパス・base branch名を記録する (クリーンアップで使う)

### Phase 3: 実装

実装はSubAgentで行う。SubAgent同士は直接やり取りできないため、受け渡しはすべてメイン会話が構造化ブロックをパースして仲介する。プロンプトはskill内のテンプレートにタスク文脈を合成して作る。
SubAgentは毎回新規に起動し、差し戻し時も前回のSubAgentを継続しない。失敗した試行の履歴はプロンプトに含めず、`REMEDIATION` など修正に必要な情報だけを渡す。

- **implementer** ([templates/implementer-prompt.md](templates/implementer-prompt.md)): 1タスクの実装と検証を担い、`## Status Report` を返す
- **reviewer** ([templates/reviewer-prompt.md](templates/reviewer-prompt.md)): 実装を敵対的に検証し (受け入れ基準・TDDのRED証跡・boundary violationを含む)、`## Review Verdict` を返す

SubAgentのmodel選択は、環境のグローバル指示 (CLAUDE.md, AGENTS.md等) のモデル指針を最優先する。指針が無ければメイン会話と同等のモデルをデフォルトとし、定型的・機械的な作業に限りimplementerに軽量モデルを指定してよい。reviewerにはimplementerと同等以上のモデルを使う。

実装を始める前に、リポジトリから正規の検証コマンドを洗い出し、`TEST_COMMANDS` / `LINT_COMMANDS` / `BUILD_COMMANDS` として保持する。探索順はmanifest類 → タスクランナー → CI設定 → README。リポジトリの自動化が既に使っているコマンドを優先する。

Phase 3の間の制約:

- ループ内で `git reset --hard` 等の破壊的リセットを行わない
- commit・push・PR作成はPhase 4まで行わない
- SubAgentの完了主張を検証の代わりにしない。判定は構造化フィールドと、reviewer・最終検証の実行結果だけで行う

#### Phase 3.1: タスクごとのイテレーション

タスクキューの順に、**1タスク = 1イテレーション**で直列に処理する (`Blocked by` は順序の決定にだけ使い、並列実行しない)。複数タスクを1つのSubAgentにまとめて渡さない。

1. **task statusの更新**: 着手時に `tasks.md` の該当taskを `Status: in-progress` へ更新する (tasks.mdがある場合。メインrepo側のパスで)
2. **implementerの起動**: テンプレートに以下を合成して起動する
   - worktreeの絶対パス、base branch名と作業branch名
   - specのタイトル・本文の要約と、**contract (Requirements / Boundaries / Acceptance Criteria)**
   - 担当タスクの説明・受け入れ基準・Boundary、Phase 1で決めた実装方針
   - タスクに関係する検証コマンド
   - これまでのImplementation Notes (あれば)
3. **STATUSの処理**: `## Status Report` の `- STATUS:` フィールドだけをパースする。構造化値が無い・曖昧な場合は1回だけ再要求する
   - `READY_FOR_REVIEW` → 4へ進む
   - `NEEDS_CONTEXT` → `MISSING` の不足情報を用意して1回だけ再起動する。解決しなければ中止し、Phase 1と同じ形式でユーザーに質問する
   - `BLOCKED` → 中止し、`BLOCKER` と `BLOCKER_REMEDIATION` を報告する
4. **reviewerの起動**: テンプレートに、タスク文脈・contract・検証コマンド・implementerのStatus Report (参照用) を合成して起動する
5. **VERDICTの処理**: `## Review Verdict` の `- VERDICT:` フィールドだけをパースする
   - `APPROVED` → タスク完了。`tasks.md` の該当taskを `Status: done` へ更新して進捗を永続化する (Issueへは書き込まない)。その後、次のタスクへ進む
   - `REJECTED` → `REMEDIATION` と `FINDINGS` を添えてimplementerを再起動する。同一タスクの差し戻しは**最大2周**とし、2周後もREJECTEDなら中止して未解決の指摘を報告する
6. **知見の伝播**: タスク横断で有用な発見は、`tasks.md` 末尾の `## Implementation Notes` へ1行で永続化し、以降のimplementerのプロンプトに含める

中断後に再実行された場合は、Phase 1のキュー構築が完了taskをスキップするため、未完了タスクから再開される。

#### Phase 3.2: 最終検証とAcceptance Criteria照合

全タスク完了後、次の2つを行う。

1. **検証コマンドの実行**: SubAgentに検証コマンド全体の実行を依頼し、コマンド・exit code・失敗内容を報告させる。検証コマンドが見つからないリポジトリではスキップし、その事実をPhase 5に含める
2. **Acceptance Criteriaの照合**: specのAcceptance Criteriaを1件ずつ、実装と検証結果に照合する。各criterionについて、それを満たす変更・テスト・実行結果を特定して充足を判定する (SubAgentに依頼してよい)。specにAcceptance Criteriaが無いdoc modeでは省略する

- 検証コマンドがすべて成功し、全ACが充足 → Phase 4へ進む
- 検証コマンドの失敗、またはACの未充足 → 内容を添えてimplementerに差し戻す (合わせて最大2周)。収束しなければ中止し、未充足のcriterionを明示して報告する

### Phase 4: commitと配送 (git-commit / github-pr-create に連結)

メイン会話が、作業ディレクトリをworktreeの絶対パスに切り替えた上で実行する。commit message・PR本文などの外部向け出力には、`.mjun/` 配下のパスや内部spec文書を含めない (外部へ見せるspecの参照はGitHub Issue番号だけを使う)。

1. **`git-commit` skillでcommitを作成する**: 対象はPhase 3でworktree内に作られたすべての変更
2. **`--no-pr` の場合**: ここで配送を終える。Phase 5へ進む
3. **`--pr` の場合、`github-pr-create` skillでPRを作成する**:
   - Phase 1で決めた出力言語を `language` として渡し、`--draft` の指定を転送する
   - **specが `Source: #N` を持つ場合はそのIssue番号を `spec` として渡す** (PR本文の `Closes #N` に使われる)。純Local specでは渡さない (specは内部文書であり、PR本文で言及しない。Contract reviewには `github-pr-review` の `--spec` を使う)
   - push・PRタイトルと本文の生成・PR作成はすべて連結先skillが行う。手順を再実装しない
4. **結果を検証する**: 作成されたPRのURLと状態を `gh pr view <url> --json url,state` で確認する。`Source: #N` を持つspecでは本文に `Closes #N` が含まれるか確認し、無ければ `gh pr edit --body-file` で追記する。PR作成に失敗した場合はworktreeをクリーンアップせず、エラーを伝えて中止する

### Phase 5: 結果の表示

- **Source**: Issue番号とタイトル / specパス
- **Branch**: 作成したbranch名
- **PR**: 作成したPRのURL (`--no-pr` の場合は「PRなし。branch `<name>` に成果があります」)
- **変更概要**: ファイル数、追加/削除行数 (`git diff --stat <base>..HEAD`)
- **タスク進捗**: 完了タスク数と、スキップした完了済みタスク数 (resume時)
- **AC coverage**: Acceptance Criteriaの充足状況 (充足数 / 総数と、各criterionの判定)

### Phase 6: worktreeクリーンアップ

- **`--pr` で成功した場合**: `git worktree remove --force <worktree-path>` → `git branch -D <branch-name>` (remote branchはPRのheadとして残る)
- **`--no-pr` で成功した場合**: worktreeだけを削除し、**local branchは削除しない**。merge / pushの判断はユーザーに委ねる
- **PR作成に失敗した場合**: worktreeとlocal branchを残して報告する (手動修復の余地を残す)
- **Phase 2〜5の途中でエラーまたはユーザーの中止により中断した場合**: worktreeを削除し、commitが存在するならbranchを残してその旨を報告する。commitが無ければbranchも削除する
- クリーンアップに失敗した場合はユーザーに警告する
