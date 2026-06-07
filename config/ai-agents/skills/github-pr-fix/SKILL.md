---
name: github-pr-fix
description: PRの全問題（コンフリクト、CI失敗、レビューコメント）を自動検出してgit worktree内で修正するSkill。
allowed-tools: Skill, Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*), Bash(jq:*), Bash(bash:*), Bash(mkdir:*), Bash(rm:*), Bash(test:*), Bash(basename:*)
---

# GitHub PR Fix

このSkillは、指定されたPRの全問題（コンフリクト、CI失敗、レビューコメント）を自動検出して修正するためのものです。
修正作業はPRごとに専用のGit worktree内で行われ、元の作業ツリーはPR情報の取得とworktreeの作成以外では使用しません。
修正内容はPRの言語に合わせて生成され、ユーザーへの報告も同じ言語で行われます。

このSkillは3つのサブSkillを正しい順序でオーケストレーションし、PRの全問題を修正する。

- `git-fix-conflict`: コンフリクトの解消
- `github-fix-ci`: CI失敗の修正
- `github-resolve-pr-comment`: レビューコメントへの対応

**重要**: 修正作業は必ず専用 worktree 内で行う。Skillを起動した元の作業ツリーでは、PR情報の取得と worktree 作成以外のファイル編集・commit・push を行わない。

## 引数

- `PR number`: 修正するPR番号（任意、デフォルトは現在のブランチのPR）

## 0. 事前チェック

1. 対象PRの特定:
   - 引数でPR番号が指定されている場合はそのPRを使用する
   - 引数が指定されていなければ、現在のブランチに紐づくPRを使用する
   - PRが存在しない場合はエラーメッセージを表示して中止
2. `owner/repo` を取得: `gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'`
3. PRの `baseRefName` / `headRefName` / `headRepositoryOwner` / `isCrossRepository` を取得する
4. cross repository PR の場合は、現在の認証ユーザーが head repository へ push できるかを確認する。push できない場合は、修正内容を作れてもPRへ直接反映できないため中止して理由を報告する
5. PRの初期ステータスサマリーを表示

## 1. PR言語の検出

- PRのタイトルと本文を分析して言語を検出する（例: 日本語、英語）
- **重要**: すべての報告とサマリーは検出された言語で記述すること
- 各サブSkillも同じ言語を独立して検出する
- 言語が曖昧な場合は英語をデフォルトとする
- 最終サマリー用テンプレートは検出された言語に応じてここで決定する:
  - English/default: [`references/summary_template.md`](references/summary_template.md)
  - Japanese: [`references/summary_template_ja.md`](references/summary_template_ja.md)

## 2. 修正用 worktree の作成

1. `<repo-root>/.tmp/<repo-name>-worktrees/pr-<number>-fix` を専用 worktree path とする。
2. 同じ path の worktree が存在し、未commit変更がある場合は中止する。clean な場合のみ作り直してよい。
3. PR head と base branch を fetch する:

   ```bash
   git fetch origin +pull/<number>/head:refs/pr-fix/<number>/head
   git fetch origin +<base-ref-name>:refs/pr-fix/<number>/base
   ```

4. PR の `headRefName` を専用 worktree に checkout し、worktree 内の branch が PR head branch であることを確認する。
5. Phase 3 以降は、すべての操作を `<worktree-path>` 配下で実行する。

## 3. 問題の検出

3種類の問題を並列に検出し、検出結果に応じて Phase 4 で必要なSkillだけ呼び出す。
検出は `<worktree-path>` を cwd とし、PR番号を明示して実行する。

- **1. コンフリクト**: `mergeable` が `CONFLICTING` の場合のみ対応する。`MERGEABLE` / `UNKNOWN` はスキップする。
- **2. CI失敗**: `FAILURE` / `CANCELLED` / `TIMED_OUT` の check がある場合のみ対応する。全て実行中の場合はステータスを報告し、セクション4のStep 2はスキップする。
- **3. 未対応レビューコメント**: inline review thread の unresolved 数が 1 件以上の場合のみ対応する。unresolved 数は [`scripts/fetch_review_threads.sh`](scripts/fetch_review_threads.sh) の `--only-unresolved` で取得し、review 全体の state だけでは判定しない。

## 4. 検出した問題への対応

検出された問題に対して、以下の順序でサブSkillを呼び出す。**前のステップが失敗しても後続のステップは試みる**。
各サブSkillは必ず `<worktree-path>` を cwd として実行する。サブSkillへの引き継ぎには次の制約を明示する:

- PR番号: `<number>`
- 作業ディレクトリ: `<worktree-path>`
- 修正対象 branch: `<head-ref-name>`
- base branch: `<base-ref-name>`
- worktree 外のファイルを編集しない
- commit / push は `<worktree-path>` 内の PR head branch から行う

### Step 1: コンフリクトの解消

3.1で`CONFLICTING` の場合のみ:

- `git-fix-conflict` Skill を `<worktree-path>` 内で実行
- 完了を待ってから、再度 `gh pr view --json mergeable --jq '.mergeable'` でコンフリクトが解消されたことを確認する
- 検出された言語でステータスを報告する

### Step 2: CI失敗の修正

3.2で失敗チェックがある場合のみ:

- `github-fix-ci` Skill を `<worktree-path>` 内で実行
- 完了を待つ。プッシュ後にCIが再実行されることに注意する
- 検出された言語でステータスを報告する

### Step 3: レビューコメントへの対応

3.3で未解決スレッドがある場合のみ:

- `github-resolve-pr-comment` Skill を `<worktree-path>` 内で実行（同Skillはレビューコメントへのリプライを常に投稿する）
- 完了後、再度 [`scripts/fetch_review_threads.sh`](scripts/fetch_review_threads.sh) の `--only-unresolved` で unresolved 数の差分を取って報告する
- 検出された言語でステータスを報告する

## 5. 最終確認

1. `<worktree-path>` 内で最終状態を確認する:

   ```bash
   git status --short
   git log --oneline --max-count=5
   gh pr view <number> --json url,mergeable,mergeStateStatus
   gh pr checks <number>
   ```

2. commit 済みだが未pushの変更が残っている場合は、`<worktree-path>` 内から PR head branch へ push する
3. 未commit変更が残っている場合は、対象サブSkillの失敗として扱い、内容を検出された言語で報告する
4. worktree は原則として削除しない。ユーザーが後で状態を確認できるように、最終サマリーへパスを含める

## 6. 最終サマリー

検出された問題に応じて、1で決定したテンプレートを使用して表示する。

## 注意事項

- 大きな変更の前にはユーザーに確認を求める
- 修正・commit・push は必ず専用 worktree 内で実行する。元の作業ツリーはPR情報取得と worktree 作成だけに使う
- レビューコメントへの対応時は、`github-resolve-pr-comment` に常にリプライを投稿させる（Phase 4 Step 3）
- レビューコメントの未解決判定は [`scripts/fetch_review_threads.sh`](scripts/fetch_review_threads.sh) の `--only-unresolved` を使う。review 全体の state ベースの判定は unresolved thread を取りこぼすので使わない
