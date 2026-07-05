---
name: git-fix-conflict
description: Git/GitHubのmerge、rebase、cherry-pick、revert、apply、PRなどで発生したコンフリクトを検出して解消するSkill。ユーザーが「コンフリクトを直して」「マージコンフリクトを解消して」のように依頼したら使うこと。
allowed-tools: Read, Edit, Write, Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(rg:*), Bash(head:*), Bash(tail:*), Bash(jq:*), Bash(test:*), Bash(make:*), Bash(npm:*), Bash(pnpm:*), Bash(yarn:*), Bash(go:*), Bash(cargo:*), Bash(uv:*)
---

# Resolve Git Conflicts

## Arguments

- `--dry-run`: 検出したコンフリクトファイル一覧と解消方針の提案のみを提示し、ファイル編集・`git add`・commit・pushを一切行わない

## タスク

0. **事前チェック**:
   - 現在のブランチ、Git状態、進行中の操作、未解決ファイルを確認する
   - 必要に応じて現在のPR情報を取得する
   - `git diff --name-only --diff-filter=U` で未解決ファイルを確認する
   - 未解決ファイルがある場合は、現在進行中の操作（merge / rebase / cherry-pick / revert / apply / am 等）を解消対象にする
   - 未解決ファイルがなく、現在のブランチにPRがあり `mergeable == CONFLICTING` の場合は、PR base branch を merge してコンフリクト解消を開始する
   - 未解決ファイルがなく、PRのコンフリクトも検出されない場合は「コンフリクトは検出されませんでした」と報告して終了する

1. **出力言語の検出**:
   - PRがある場合はPRのタイトルと本文を分析して言語を検出する（例: 日本語、英語）
   - PRがない場合は、ユーザーの依頼言語とリポジトリ内の直近のコミットメッセージを参考にする
   - **重要**: すべてのコミットメッセージと報告は検出された言語で記述すること
   - 言語が曖昧な場合は英語をデフォルトとする

2. **最新の変更を取得**:
   - GitHub PR のコンフリクトを解消する場合のみ、originからfetchしてbase branchを特定する
   - すでに merge / rebase / cherry-pick / revert / apply / am が進行中の場合は、新しい merge や rebase を開始しない

3. **コンフリクト解消の開始または継続**:
   - すでにコンフリクト中の場合は、その進行中の操作を継続して解消する
   - PRが `CONFLICTING` でまだコンフリクト中でない場合は、`git merge origin/<base-branch>` で開始する
   - rebase 中のコンフリクトは解消対象に含める。ただし、新規に rebase を開始しない

4. **コンフリクトファイルの特定と分析**:
   - コンフリクト一覧: `git diff --name-only --diff-filter=U`
   - 各ファイルのコンフリクト領域を表示

   `--dry-run` が指定された場合は、ここで検出したコンフリクトファイル一覧と解消方針の提案のみを提示し、ファイル編集・`git add`・commit・pushを一切行わず終了する。

5. **各コンフリクトの解消**:
   - 各コンフリクトファイルについて:
     - コンフリクトマーカー（`<<<<<<<`, `=======`, `>>>>>>>`）を表示
     - 両方のバージョンを分析:
       - **HEAD (ours)**: 現在のブランチの変更
       - **theirs**: ベースブランチの変更
     - 正しい解消方法を判断:
       - 自分側を採用
       - 相手側を採用
       - 両方の変更を統合
       - 新しい実装を記述
     - 解消を適用
     - 判断理由を説明（検出された言語で）

6. **解消済みとしてマーク**:
   - 解消したファイルをステージング: `git add <resolved-files>`
   - 進行中の操作に応じて完了処理を行う:
     - merge: 検出された言語で merge commit を作成
     - rebase: `git rebase --continue`
     - cherry-pick: `git cherry-pick --continue`
     - revert: `git revert --continue`
     - am: `git am --continue`
     - apply: staging まで行い、必要な commit は状況に応じて作成する
   - merge commit のメッセージ例:
     - 英語: `merge: resolve conflicts with <base-branch>`
     - 日本語: `merge: <base-branch>とのコンフリクトを解消`

7. **変更をプッシュ**:
   - PR branch へ反映する必要がある場合は `git push`
   - rebase などで履歴が書き換わっている場合は、push前にユーザーへ確認し、必要な場合のみ `git push --force-with-lease` を使う

8. **結果を返す**（検出された言語で）:
   - English: [`references/summary_template.md`](references/summary_template.md)
   - Japanese: [`references/summary_template_ja.md`](references/summary_template_ja.md)

## 注意事項

- 複雑なコンフリクト（大きなファイル、アーキテクチャの変更）の場合は、コンフリクトを表示してユーザーに判断を求める
- 新規にrebaseを開始しない。rebase中のコンフリクトは解消して `git rebase --continue` する
- 履歴を書き換えるpushが必要な場合は、必ず事前にユーザーへ確認し、`--force` ではなく `--force-with-lease` を使用する
- 解消後、問題がないことを確認するためにテストの実行を行う
