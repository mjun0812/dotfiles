---
name: github-pr-fix
description: PRの全問題 (コンフリクト、CI失敗、レビューコメント) を自動検出してgit worktree内で修正するSkill。ユーザーが「PRの問題を全部直して」「PRをまとめて修正して」のように依頼したら使うこと。個別のコンフリクト解消のみはgit-fix-conflict、CI修正のみはgithub-fix-ciを使う。
allowed-tools: Skill, Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*), Bash(jq:*), Bash(bash:*), Bash(mkdir:*), Bash(rm:*), Bash(test:*), Bash(basename:*)
---

# GitHub PR Fix

指定されたPRの全問題(コンフリクト、CI失敗、レビューコメント)を自動検出して修正するSkill。
修正作業はPRごとの専用Git worktree内で行い、修正内容はPRの言語に合わせて生成し、ユーザーへの報告も同じ言語で行う。
**3つのサブSkillを正しい順序でオーケストレーションし、検出された問題に対応するSkillだけを呼び出す**。

- `git-fix-conflict`: コンフリクトの解消
- `github-fix-ci`: CI失敗の修正
- `github-resolve-pr-comment`: レビューコメントへの対応

修正・commit・pushは必ず専用worktree内で行う。Skillを起動した元の作業ツリーでは、PR情報の取得とworktree作成以外のファイル編集・commit・pushを行わない。

## Arguments

- `PR number` (Optional): 修正するPR番号。省略時は現在のブランチに紐づくPRを対象とする

## Task

### Phase 1: 事前チェック

1. 対象PRの特定:
   - 引数でPR番号が指定されている場合はそのPRを使用する
   - 引数が指定されていなければ、現在のブランチに紐づくPRを使用する
   - PRが存在しない場合はエラーメッセージを表示して中止
2. `owner/repo` を取得: `gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'`
3. PRの `baseRefName` / `headRefName` / `headRepositoryOwner` / `isCrossRepository` を取得する
4. cross repository PR の場合は、現在の認証ユーザーが head repository へ push できるかを確認する。push できない場合は、修正内容を作れてもPRへ直接反映できないため中止して理由を報告する
5. push先 `<push-remote>` を決定する。PR head branch は head repository にあるため、cross repository PR で `origin` (base repository) へ push しないこと:
   - 同一リポジトリのPR: `origin`
   - cross repository PR: head repository のURL。`origin` のURL形式に合わせて `https://github.com/<head-repository-owner>/<head-repo-name>.git` または `git@github.com:<head-repository-owner>/<head-repo-name>.git` を組み立てる
6. PRのタイトルと本文から言語を検出する (例: 日本語、英語)。曖昧な場合は英語をデフォルトとする。検出はここで1回だけ行い、すべての報告とサマリーをこの言語で記述し、Phase 4の引き継ぎ制約に含めてサブSkillへ渡す (サブSkillに独立して再検出させない)
7. 最終サマリー用テンプレートを検出された言語に応じて決定する:
   - English/default: [`references/summary_template.md`](references/summary_template.md)
   - Japanese: [`references/summary_template_ja.md`](references/summary_template_ja.md)

### Phase 2: 修正用worktreeの作成

1. `<repo-root>/.tmp/<repo-name>-worktrees/pr-<number>-fix` を専用 worktree path とする。
2. 同じ path の worktree が存在し、未commit変更がある場合は中止する。clean な場合のみ作り直してよい。
3. PR head と base branch を fetch する: `git fetch origin +pull/<number>/head:refs/pr-fix/<number>/head` および `git fetch origin +<base-ref-name>:refs/pr-fix/<number>/base`
4. `git worktree add -B pr-fix/<number> <worktree-path> refs/pr-fix/<number>/head` で、`headRefName` ではなく fetch済みの ref から専用local branchを作って checkout する。`headRefName` はPR head branch名としてpush先の判定に使う。checkout対象にはしない。fork PR や同名branchの衝突で別branchを修正しないよう、worktreeの `HEAD` が `refs/pr-fix/<number>/head` の commit SHA と一致することを確認する。
5. Phase 3 以降は、すべての操作を `<worktree-path>` 配下で実行する。

### Phase 3: 問題の検出

3種類の問題を並列に検出し、検出結果に応じて Phase 4 で必要なSkillだけ呼び出す。
検出は `<worktree-path>` を cwd とし、PR番号を明示して実行する。

- **1. コンフリクト**: `mergeable` が `CONFLICTING` の場合のみ対応する。`MERGEABLE` / `UNKNOWN` はスキップする。
- **2. CI失敗**: `FAILURE` / `CANCELLED` / `TIMED_OUT` の check がある場合のみ対応する。全て実行中の場合はステータスを報告し、Phase 4 の Step 2 はスキップする。
- **3. 未対応レビューコメント**: inline review thread の unresolved 数が 1 件以上の場合のみ対応する。unresolved 数は [`scripts/fetch_review_threads.sh`](scripts/fetch_review_threads.sh) の `--only-unresolved` で取得し、review 全体の state だけでは判定しない (state ベースの判定は unresolved thread を取りこぼす)。

### Phase 4: 検出した問題への対応

検出された問題に対して、以下の順序でサブSkillを呼び出す。**前のステップが失敗しても後続のステップは試みる**。大きな変更の前にはユーザーに確認を求める。
各サブSkillは必ず `<worktree-path>` を cwd として実行する。サブSkillへの引き継ぎには次の制約を明示する:

- PR番号: `<number>`
- 作業ディレクトリ: `<worktree-path>`
- 修正対象 branch: `<head-ref-name>`
- base branch: `<base-ref-name>`
- 出力言語: Phase 1で検出した言語 (リプライ・commit message・報告に使用する)
- worktree 外のファイルを編集しない
- commit / push は `<worktree-path>` 内の PR head branch から行う
- push時は必ず `git push <push-remote> HEAD:<head-ref-name>` の形式でPR head branchへ明示的に反映すること (worktreeのlocal branch名は`pr-fix/<number>`でありPR head branch名と異なるため。`<push-remote>` はPhase 1で決定したもの)

#### Step 1: コンフリクトの解消

Phase 3でコンフリクト (`CONFLICTING`) が検出された場合のみ:

- `git-fix-conflict` Skill を `<worktree-path>` 内で実行
- 完了を待ってから、再度 `gh pr view --json mergeable --jq '.mergeable'` でコンフリクトが解消されたことを確認する
- 検出された言語でステータスを報告する

#### Step 2: CI失敗の修正

Phase 3で失敗チェックが検出された場合のみ:

- `github-fix-ci` Skill を `<worktree-path>` 内で実行
- 完了を待つ。プッシュ後にCIが再実行されることに注意する
- 検出された言語でステータスを報告する

#### Step 3: レビューコメントへの対応

Phase 3で未解決スレッドが検出された場合のみ:

- `github-resolve-pr-comment` Skill を `<worktree-path>` 内で実行 (同Skillにはレビューコメントへのリプライを常に投稿させる)
- 完了後、再度 [`scripts/fetch_review_threads.sh`](scripts/fetch_review_threads.sh) の `--only-unresolved` で unresolved 数の差分を取って報告する
- 検出された言語でステータスを報告する

### Phase 5: 最終確認

1. `<worktree-path>` 内で未commit変更と直近のcommitを確認し、`gh pr view <number> --json url,mergeable,mergeStateStatus` と `gh pr checks <number>` でPRの最終状態を確認する
2. commit 済みだが未pushの変更が残っている場合は、`<worktree-path>` 内から `git push <push-remote> HEAD:<head-ref-name>` で PR head branch へ push する
3. 未commit変更が残っている場合は、対象サブSkillの失敗として扱い、内容を検出された言語で報告する

### Phase 6: 最終サマリー

検出された問題に応じて、Phase 1で決定したテンプレートを使用して表示する。

### Phase 7: クリーンアップ

修正が完了した場合も、途中のエラーまたはユーザーの中止により中断した場合も行う:

1. Phase 2でfetchした一時refを削除する: `git update-ref -d refs/pr-fix/<number>/head` および `git update-ref -d refs/pr-fix/<number>/base`
2. `git worktree remove --force <worktree-path>`
3. `git branch -D pr-fix/<number>`
4. クリーンアップに失敗した場合は、失敗した項目をユーザーに警告する
