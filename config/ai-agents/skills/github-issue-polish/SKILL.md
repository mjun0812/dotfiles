---
name: github-issue-polish
description: >-
  GitHub issueを「issueだけで実装できる」状態まで磨き上げるSkill。
  コードベース調査・設計判断・worktreeでのお試し実装で修正方針を検証し、承認を得てからissue本文を書き換える。
  ユーザーが「issueを磨いて」「#Nをpolishして」「issueを実装できるレベルに詰めて」のように依頼したら使うこと。
  起票はgithub-issue-create、実装からPR作成まではgithub-issue-resolveを使う。
allowed-tools: Bash(gh:*), Bash(git:*), Bash(mkdir:*), Bash(rm:*), Bash(cd:*), Bash(ls:*), Bash(cat:*), Bash(mktemp:*), Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Polish GitHub Issue

GitHub操作は必ず`gh` CLIで行うこと。GitHub connector/pluginやMCPのGitHubツールは使用しない。

指定されたissueを、実装者が追加調査なしで着手できる「issueだけで実装できる」状態まで磨き上げるSkill。コードベース調査で原因と変更箇所を特定し、設計の分岐点を根拠付きで決定し、worktreeでのお試し実装で修正方針を検証した上で、承認を得てissue本文を書き換える。

## Arguments

- `issue` (必須): 対象のissue番号。先頭の `#` は省略可 (例: `123` または `#123`)
- `language` (任意): 磨き上げ後の本文の言語 (例: `ja`, `en`)。デフォルトは元issue本文の言語に合わせる
- `--skip-trial` (任意): お試し実装 (Phase 4) を省略する
- `--dry-run` (任意): 磨いた本文の提示 (Phase 5) で停止し、issueへの書き込みは一切行わない

## Target Structure

磨き上げ後の本文は次のセクション構成とする。元issueに情報がなく、調査でも埋められないセクションは省略する (空のセクションやプレースホルダーを残さない)。

1. **背景・目的**: なぜやるか。実装判断のブレを防ぐためのwhyの共有
2. **現状**: 現在の動作。バグなら再現手順・エラーログ
3. **原因分析**: root causeを `path/to/file:行番号` 単位で記述
4. **修正方針**: 採用案に加え、却下した代替案と却下理由も記述
5. **変更対象ファイル**: ファイルごとに「何をどう変えるか」を1行ずつ
6. **テスト方針**: 追加・変更するテストと実行コマンド
7. **やらないこと**: スコープ外の明示
8. **検証メモ**: お試し実装の結果 (実行したテスト・結果・気付いた落とし穴)
9. **意思決定ログ**: 論点 / 決定 / 根拠 / 確信度の表。確信度が低いものは「要確認」と明示する
10. **完了条件**: checkbox形式。機械的に判定できる表現にする

## Task

### Phase 0: 前提取得

以下を取得して状況を確認する:

- gh認証確認: `gh auth status` (失敗時は停止し、認証を案内する)
- リポジトリ情報: `gh repo view --json defaultBranchRef,nameWithOwner`
- 対象issue: `gh issue view <number> --json number,state,title,body,labels,comments,url`
- issueが `state: CLOSED` の場合は中止し、「issue #N は既にclosedです」と報告する

### Phase 1: ギャップ分析

現在のissue本文とコメントをTarget Structureと突き合わせ、欠落しているセクション・曖昧な記述・実装者が追加調査を要する箇所を列挙する。コメントでの合意事項は本文へ反映する対象として扱う。

### Phase 2: コードベース調査

ギャップを埋めるためにコードベースを調査する:

- 関連コードを読み、原因・変更箇所を `path/to/file:行番号` 単位で特定する
- 既存の実装パターン・再利用できる関数やユーティリティを把握し、修正方針の材料にする
- 調査中にissueのスコープ外の問題を見つけた場合は、本文に混ぜず「やらないこと」への記載と別issue化の提案に回す

### Phase 3: 設計判断

実装方針の分岐点をすべて列挙し、各分岐を調査結果に基づき根拠付きで自分で決定する:

- 採用案と、却下した代替案・却下理由を記録する
- 決定できない分岐はユーザーに質問せず、暫定決定した上で確信度を低くつける
- 決定は「論点 / 決定 / 根拠 / 確信度」の表 (意思決定ログ) にまとめ、確信度が低いものは「要確認」として人間レビューの焦点にする

### Phase 4: お試し実装

`--skip-trial` 指定時はこのPhaseを省略する。修正方針の実現可能性を一時worktreeで検証する:

1. worktreeを作成する: branch名は `polish/<issue-number>-trial`、パスは `<repo-root>/.tmp/<repo-name>-worktrees/<branch-name>`。既存branch・worktreeと衝突する場合は末尾に `-2`, `-3` を付ける
   - `git worktree add -b <branch-name> <worktree-path> <default-branch>`
2. worktree内で修正方針の最小実装を行い、テスト方針に沿ったテストを実行して結果を確認する
3. 検証結果 (実行したテスト・結果・気付いた落とし穴・方針の修正点) を「検証メモ」用に要約する。diff全文はissueに載せず、鍵になる数行のスニペットのみ許可する
4. 検証で方針の問題が見つかった場合はPhase 3に戻り、意思決定ログを更新する
5. **worktreeとbranchは検証後必ず削除する**。途中でエラーが出た場合やユーザーが中止した場合も同様:
   - `git worktree remove --force <worktree-path>` → `git branch -D <branch-name>`
   - 削除に失敗した場合はユーザーに警告する

### Phase 5: 本文生成と全文提示

Target Structureに沿って本文を再構成し、磨き上げ後の全文と変更点サマリ (追加・変更したセクションと理由) をユーザーに提示する。

- タイトルも内容を正確に表すよう必要なら改善案を含める
- `--dry-run` 指定時はここで終了する

### Phase 6: 承認と反映

AskUserQuestionで承認を取る (AskUserQuestionが使えない環境では、同等の選択肢をテキストで提示して回答を待つ):

1. 「反映する / 修正して再提示 / キャンセル」
2. 「修正して再提示」の場合は指摘を反映してPhase 5からやり直す
3. 「キャンセル」の場合はissueに書き込まず終了する

承認後に反映する:

- 本文はエスケープ問題を避けるため一時ファイル経由で上書きする: `gh issue edit <number> --body-file <tmpfile>`
- 変更点サマリを `gh issue comment` で1件追記する (body編集はwatcherに通知されないため、通知とトレーサビリティをコメントで補う)

### Phase 7: 結果報告

以下を簡潔にまとめて出力する:

- **Issue**: #N タイトル / URL
- **変更点サマリ**: 追加・変更したセクション
- **要確認事項**: 意思決定ログで確信度が低い項目の一覧
- **別issue化の提案**: Phase 2で見つけたスコープ外の問題 (あれば)
