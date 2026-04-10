---
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*), SlashCommand
argument-hint: [PR number] [--reply]
description: PRの全問題（コンフリクト、CI失敗、レビューコメント）を自動検出して修正する。
context: fork
---

# PR の全問題を修正

## 引数

- `PR number`: 修正するPR番号（任意、デフォルトは現在のブランチのPR）
- `--reply`: 対応後にGitHubにリプライコメントを投稿（任意）

## コンテキスト

- 現在のブランチ: !`git branch --show-current`
- 現在のPR: !`gh pr view --json number,url,mergeable,mergeStateStatus 2>/dev/null || echo "No PR found"`
- PRタイトル: !`gh pr view --json title --jq '.title' 2>/dev/null`
- PR本文: !`gh pr view --json body --jq '.body' 2>/dev/null | head -30`
- CIステータス: !`gh pr checks --json name,state,conclusion 2>/dev/null || echo "No checks"`
- 保留中のレビュー: !`gh pr view --json reviews --jq '[.reviews[] | select(.state == "CHANGES_REQUESTED")] | length' 2>/dev/null || echo "0"`

## タスク

このコマンドは3つのサブコマンドを正しい順序でオーケストレーションし、PRの全問題を修正する。

0. **事前チェック**:
   - $ARGUMENTS にPR番号が指定されている場合はそのPRを使用
   - そうでなければ、現在のブランチに紐づくPRを使用
   - PRが存在しない場合はエラーメッセージを表示して中止
   - PRの初期ステータスサマリーを表示

1. **PR言語の検出**:
   - PRのタイトルと本文を分析して言語を検出する（例: 日本語、英語）
   - **重要**: すべての報告とサマリーは検出された言語で記述すること
   - サブコマンドも同じ言語を使用する（各サブコマンドが独立して検出）
   - 言語が曖昧な場合は英語をデフォルトとする

2. **ステップ1: コンフリクトの確認と修正**:
   - マージステータスを確認: `gh pr view --json mergeable --jq '.mergeable'`
   - `CONFLICTING` の場合:
     - `/pr:fix-conflicts` を実行
     - 完了を待つ
     - コンフリクトが解消されたことを確認
   - `MERGEABLE` の場合: 次のステップへスキップ
   - 検出された言語でステータスを報告

3. **ステップ2: CI失敗の確認と修正**:
   - CIステータスを確認: `gh pr checks`
   - 失敗したチェックがある場合:
     - `/github:fix-ci` を実行
     - 完了を待つ
     - 注意: プッシュ後にCIが再実行される
   - すべてのチェックが成功している場合: 次のステップへスキップ
   - チェックがまだ実行中の場合: ステータスを報告して続行
   - 検出された言語でステータスを報告

4. **ステップ3: レビューコメントの確認と対応**:
   - 保留中のレビューコメントを確認: `gh pr view --json reviews,comments`
   - 未対応のコメントがある場合:
     - `/pr:respond-comment --reply` を実行
     - 完了を待つ
   - 保留中のコメントがない場合: スキップ
   - 検出された言語でステータスを報告

5. **最終サマリー**（検出された言語で）:

### 英語フォーマット

```markdown
## PR Fix Summary

### Status

| Check     | Before | After |
| --------- | ------ | ----- |
| Conflicts | ❌/✅    | ✅     |
| CI        | ❌/✅    | ✅/⏳   |
| Reviews   | ❌/✅    | ✅     |

### Actions Taken

- [ ] Resolved X merge conflicts
- [ ] Fixed X CI failures
- [ ] Addressed X review comments

### Commits Created

- `abc1234` - merge: resolve conflicts with main
- `def5678` - fix: resolve CI failures
- `ghi9012` - fix: address review comments
```

### 日本語フォーマット

```markdown
## PR修正サマリー

### ステータス

| チェック     | 修正前 | 修正後 |
| ------------ | ------ | ------ |
| コンフリクト | ❌/✅    | ✅      |
| CI           | ❌/✅    | ✅/⏳    |
| レビュー     | ❌/✅    | ✅      |

### 実行したアクション

- [ ] X件のマージコンフリクトを解消
- [ ] X件のCI失敗を修正
- [ ] X件のレビューコメントに対応

### 作成したコミット

- `abc1234` - merge: mainとのコンフリクトを解消
- `def5678` - fix: CI失敗を修正
- `ghi9012` - fix: レビューコメントに対応
```

## 注意事項

- 各ステップは問題が検出された場合のみ実行される
- あるステップが失敗しても、後続のステップは実行を試みる
- 大きな変更の前にはユーザーに確認を求める
- 各ステップの完了後に検出された言語で進捗を報告する
