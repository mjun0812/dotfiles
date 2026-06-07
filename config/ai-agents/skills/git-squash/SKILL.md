---
name: git-squash
description: 現在のbranchのcommitを自動でsquash・整理し、必要に応じてforce-with-leaseでpushするSkill。言語指定可能。
allowed-tools: Bash(git:*), Bash(gh:*), Bash(jq:*), Bash(cat:*), Bash(grep:*), Bash(rg:*)
---

# Squash Commits

現在のbranchのcommitを、対話を最小化して整理する。
未指定時は論理単位で自動グルーピングし、`--one` / `-1` 指定時のみ全commitを1つにまとめる。

## Arguments

- `language`: commitメッセージと報告の言語（例: "ja", "en"）。デフォルト: English
- `--one` / `-1`: 対象commitを1つにsquashする
- `--no-push`: squash後にpushしない

## タスク

0. **事前チェック**:
   - 現在のbranch、base branch、対象commit数、作業ツリー状態、upstreamとの差分を確認する
   - default branch上では実行せず中止する
   - 対象commitが0件なら中止する。1件のみならsquash不要として終了する
   - 未commit変更がある場合は中止する。stashやcommitは自動実行しない
   - upstream側に未取得commitがある場合は中止する。履歴消失を避けるため、自動で上書きしない

1. **出力言語の決定**:
   - `language` 指定があれば従う
   - 指定がなければPRタイトル・本文、または直近commitの言語から判定する
   - 曖昧な場合はEnglishをデフォルトにする

2. **squash方針の決定**:
   - `--one` / `-1` 指定時は全commitを1つにまとめる
   - 指定がない場合は、commitのtype、変更ファイル、PR文脈を見て論理単位に自動グルーピングする
   - グループ分離が不安定な場合は、1つにまとめる方へフォールバックする

3. **commitメッセージの生成**:
   - 変更内容から自動生成する
   - Conventional Commits形式に従う
   - 2行目は必ず空行にする
   - 3行目以降に具体的な変更内容を箇条書きで記述する

4. **squashの実行**:
   - `git reset --soft origin/<base-branch>` で対象commitを解除する
   - `--one` の場合は全変更を1つのcommitとして作成する
   - 自動グルーピングの場合は、グループごとに関連ファイルをstageしてcommitする
   - 同一ファイルの変更が複数グループに混在し、`git add -p` でも安全に分離できない場合は、1つのcommitへフォールバックする

5. **push**:
   - `--no-push` 指定時はpushせず、必要なコマンドを報告する
   - それ以外は `git push --force-with-lease` を自動実行する
   - `--force-with-lease` が失敗した場合は中止し、`--force` へフォールバックしない

6. **結果の表示**:
   - English: [`references/summary_template.md`](references/summary_template.md)
   - Japanese: [`references/summary_template_ja.md`](references/summary_template_ja.md)

## 注意事項

- ユーザー確認は原則行わない。危険な状態は自動判断で中止し、理由を報告する
- `git push --force-with-lease` のみ使用し、`git push --force` は使用しない
- squash中にconflictが発生した場合は `git-fix-conflict` Skill を使って解消する
