---
name: github-issue-resolve
description: '指定したGitHub issueに対して「事前調査 → 必要なら議論コメント投稿 → worktree作成 → 実装 → PR作成」を一気通貫で実行するSkill。issueの内容を分析して技術選定や仕様の議論が必要か判断し、議論が必要な場合はissueにコメント投稿して停止、実装に進めると判断した場合のみworktreeを切って実装〜PR作成まで進める。ユーザーが「issue #N を解決して」「このissueを実装して」「issue番号 N を片付けて」「issueから実装してPRまで」のように依頼したら必ずこのSkillを使うこと。事前調査だけ・実装だけ・PR作成だけといった単一フェーズの依頼には使わない（その場合は github-issue-create / github-pr-create 等の個別Skillを使う）。'
allowed-tools: Skill, Bash(gh:*), Bash(git:*), Bash(jq:*), Bash(mkdir:*), Bash(rm:*), Bash(cd:*), Bash(ls:*), Bash(cat:*), Bash(mktemp:*), Read, Write, Edit
---

# GitHub Issue Resolve

issue番号を起点に、調査 → 議論 → 実装 → PR作成までを順に進めるSkill。
**個々の作業は既存Skillへ委譲する**。本Skillが担うのはフェーズ間の判断と引き継ぎだけであり、PR作成手順やcommit手順を独自に再実装しない。

## Arguments

- `issue` (必須): 解決対象のissue番号。先頭の `#` は省略可（例: `123` または `#123`）
- `language` (任意): issueコメント・PR本文の言語（例: `ja`, `en`）。デフォルトは `ja`。`github-pr-create` にもそのまま転送する
- `--auto` (任意): 各フェーズの確認プロンプトをスキップして自動進行する。ただし「議論が必要」と判定された場合は `--auto` でも必ず停止する（人間判断を要するため）
- `--base <branch>` (任意): worktreeの基点branch。デフォルトはdefault branch
- `--draft` (任意): draft PRとして作成（`github-pr-create` に転送）

## Task

### Phase 1: 事前調査と分析

1. 以下を取得して状況を確認する:
   - リポジトリ情報: `gh repo view --json defaultBranchRef,nameWithOwner --jq '{default: .defaultBranchRef.name, repo: .nameWithOwner}'`
   - 対象issue: `gh issue view <number> --json number,title,state,body,labels,assignees,comments,url`
   - 現在のbranch: `git branch --show-current`
   - 既存worktree: `git worktree list --porcelain`

   issueが `state: CLOSED` の場合は中止し、ユーザーに「issue #N は既にclosedです」と通知する（`--auto` でも中止）。

2. 取得したissue本文・コメント・labelを読み、以下の観点で「議論が必要か」「実装にそのまま進めるか」を判定する:

   **議論が必要と判定すべきシグナル**:
   - 仕様が曖昧（"いい感じに" / "適切に" / 入出力の定義がない / 受け入れ基準がない）
   - 複数の実装方針が並列して書かれていて、どれを採るかが明示されていない
   - 新規ライブラリ・フレームワーク・外部サービスの導入を伴う（技術選定が必要）
   - アーキテクチャの選択（同期/非同期、DB スキーマ、API の互換性破壊など）が含まれる
   - 破壊的変更（public APIの変更、データマイグレーション、設定ファイルの非互換変更）を伴う
   - 影響範囲が複数モジュール／複数サービスに及ぶ
   - issue本文に既に質問やTODOが残っている（"〜は要相談" など）

   **そのまま実装に進めて良いシグナル**:
   - bug報告で再現手順・期待動作・実際の動作が揃っている
   - typo・ドキュメント修正・依存バージョンアップ等の小規模変更
   - 受け入れ基準が明文化されている
   - labelに `good-first-issue` / `bug` / `documentation` 等が付いていて方針が明確
   - issueコメントで方針が既に合意されている（reactionや「LGTM」「進めてください」等の明示的承認）

3. 判定結果は**簡潔に**ユーザーへ提示する（1〜2文の理由 + 判定ラベル）:
   - `IMPLEMENT_READY`: 実装に進める
   - `NEEDS_DISCUSSION`: 議論が必要（issueにコメント投稿が必要）
   - `NEEDS_TECH_DECISION`: 技術選定が必要（候補と推奨を整理してissueにコメント）

4. `NEEDS_DISCUSSION` または `NEEDS_TECH_DECISION` の場合:
   1. **調査コメントのdraftを作成**（言語は `language` 引数に従う）。以下を含める:
      - 現状の理解（issueから読み取ったゴール）
      - 検討した観点・選択肢（技術選定なら候補ライブラリ・パターン、議論なら論点と取りうる方針）
      - 推奨案と理由（あれば）
      - ユーザー（issue作成者・関係者）に確認したい質問
   2. draftを表示してユーザーに提示する
   3. 投稿可否を確認する:
      - `--auto` が指定されていても **このフェーズは必ずユーザー確認を取る**（人間の判断を要するため）
      - 承認 → `gh issue comment <number> --body-file <tmpfile>` で投稿（本文はファイル経由で渡し、`--body` への直接埋め込みは禁止）
      - 却下／編集 → ユーザー指示に従いdraftを書き直し、再度確認
   4. 投稿後は**Skillを停止する**。worktree作成・実装には進まない。終了メッセージで「issueに調査コメントを投稿しました。返信を待ってから再度本Skillを実行してください」と伝える

5. `IMPLEMENT_READY` の場合のみ Phase 2 に進む。`--auto` 未指定なら「実装に進んでよいか」を1回だけ確認する

### Phase 2: worktreeの作成

1. **branch名を決定する**:
   - 形式: `<type>/<issue-number>-<slug>`
     - `<type>`: issueのlabelやタイトルから推定（`fix`, `feat`, `docs`, `chore`, `refactor` 等。判別不能なら `feat`）
     - `<slug>`: issueタイトルからkebab-caseで生成（英数字とハイフンのみ、40文字以内）
   - 例: `feat/123-add-oauth-login`, `fix/456-handle-empty-response`
   - 既に同名のlocal branchがある場合は末尾に `-2`, `-3` を付けて衝突を避ける

2. **worktreeのパスを決定する**:
   - 形式: `<repo-root>/../<repo-name>-worktrees/<branch-name>`
   - 例: `/path/to/myrepo/../myrepo-worktrees/feat-123-add-oauth-login`（branch名の `/` は `-` に置換）
   - 既存worktreeと衝突する場合は中止してユーザーに通知

3. **worktree作成**:

   ```bash
   git worktree add -b <branch-name> <worktree-path> <base-branch>
   ```

   - `<base-branch>` は `--base` の値、未指定ならdefault branch
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
3. `github-pr-create` がPR本文を生成する際、関連Issueの検出ロジックでbranch名 (`<type>/<N>-<slug>`) から `#N` が抽出されるため、自動的に `Closes #N` が本文に含まれる。これが含まれていない場合は `github-pr-create` 完了後に `gh pr edit` で `Closes #<issue-number>` を追記する
4. PR作成に失敗した場合はworktreeをクリーンアップせず（手動修正の余地を残す）、ユーザーにエラーを伝えて中止する

### Phase 5: 結果の表示

以下を簡潔にまとめて出力する:

- **Issue**: #N タイトル / URL
- **判定**: `IMPLEMENT_READY` 等のラベルと根拠（1文）
- **Branch**: 作成したbranch名
- **Worktree**: パス
- **PR**: 作成したPRのURL
- **変更概要**: ファイル数、追加/削除行数（`git diff --stat <base>..HEAD` の結果）
- **次のステップ**: worktreeを残したまま作業を続ける場合の `cd <worktree-path>` コマンドと、不要になった場合の片付けコマンド (`git worktree remove <worktree-path>` および `git branch -D <branch-name>`)

## 中止時のworktreeクリーンアップ

Phase 2 でworktreeを作成した後、Phase 3 〜 4 の途中で中止する場合のクリーンアップ手順:

1. ユーザーに「作成したworktreeを削除してよいか」を確認する（`--auto` でも確認する。実装途中の成果を失う可能性があるため）
2. 削除承認の場合:
   - worktree内に未commitの変更がないことを確認: `git -C <worktree-path> status --porcelain`
   - 未commit変更がある場合は再度警告し、ユーザーが明示的に許可した場合のみ削除する
   - `git worktree remove <worktree-path>`（未commit変更があり強制削除する場合は `--force`）
   - `git branch -D <branch-name>`（pushされていない場合のみ）
3. 削除却下の場合:
   - worktreeパスとbranch名をユーザーに伝え、後で手動で `git worktree remove` できるよう案内する

Phase 1 で中止した場合（worktree未作成）はクリーンアップ不要。

## ガードレール

- **委譲先Skillの責務は本Skillで複製しない**:
  - PR本文生成・関連Issue検出・base branch決定・push処理 → `github-pr-create`
  - commitメッセージ生成・commit分割 → `git-commit`
  - 既存PRの扱い → `github-pr-create`
- **議論フェーズで `--auto` を無視する**: 仕様の曖昧さや技術選定は人間の判断が必須。`--auto` は実装に進めると確定した後の確認プロンプトを省略するためのものであり、人間の意思決定そのものを省略するものではない
- **worktreeの作成は IMPLEMENT_READY 判定後のみ**: 議論コメント投稿のみで終わる場合にworktreeを作っても無駄なゴミになる
- **issue状態の同時実行を考慮**: 別のworktreeで同じissueの作業が進んでいないかを `git worktree list` と `gh pr list --search "is:open <issue-number> in:body"` で確認し、衝突がありそうなら警告する
- **default branch上での実行**: 本Skillはworktreeを作るため現在のbranchを変更しないが、`git worktree add` 自体は default branch にいる状態から実行することを推奨（誤って作業中のbranchに紐づくのを避けるため）
- **secret混入の警告**: 実装中に `.env` / `credentials.json` / 秘密鍵らしきファイルを変更した場合は commit 前に必ずユーザーに警告する（`git-commit` Skill側の責務だが、本Skillでも一段の安全網として意識する）

## 設計メモ

本Skillは「issueから着手するまで」と「実装してPRを出すまで」の間をつなぐ進行役として動く。
個別の操作はすべて既存Skillに委譲することで、`github-pr-create` の進化や `git-commit` の改善がそのまま反映されるようにする。
新しいフェーズや判定ロジックを追加したくなった場合は、まず「既存Skillの責務に追加できないか」を検討し、本Skillにはフェーズ間の判断と引き継ぎ以上の責務を持ち込まないこと。
