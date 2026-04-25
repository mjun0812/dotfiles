---
name: github-pr-fix-conflicts
description: 現在のPRのマージコンフリクトを検出して解消するSkill。
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*)
---

# マージコンフリクトの修正

## 引数

- `--rebase`: rebase戦略でコンフリクトを解消（任意）
- `--merge`: merge戦略でコンフリクトを解消（任意、デフォルト）

## コンテキスト

以下を取得してから作業を開始してください。

- 現在のブランチ: `git branch --show-current`
- ベースブランチ: `gh pr view --json baseRefName --jq .baseRefName 2>/dev/null || echo "main"`
- PRタイトル: `gh pr view --json title --jq '.title' 2>/dev/null`
- PR本文: `gh pr view --json body --jq '.body' 2>/dev/null | head -30`
- マージステータス: `gh pr view --json mergeable,mergeStateStatus --jq '"\(.mergeable) - \(.mergeStateStatus)"' 2>/dev/null || echo "unknown"`
- コンフリクトファイル: `git diff --name-only --diff-filter=U 2>/dev/null || echo "none"`

## タスク

0. **事前チェック**:
   - 現在のブランチにPRが存在することを確認
   - マージステータスを確認: `gh pr view --json mergeable --jq '.mergeable'`
   - `MERGEABLE` の場合、「コンフリクトは検出されませんでした」と報告（検出された言語で）して終了
   - `UNKNOWN` の場合、最新を取得して再確認

1. **PR言語の検出**:
   - PRのタイトルと本文を分析して言語を検出する（例: 日本語、英語）
   - **重要**: すべてのコミットメッセージと報告は検出された言語で記述すること
   - 言語が曖昧な場合は英語をデフォルトとする

2. **最新の変更を取得**:
   - originからfetch: `git fetch origin`
   - ベースブランチを特定: `gh pr view --json baseRefName --jq '.baseRefName'`

3. **コンフリクト解消の開始**:
   - `--rebase` フラグまたはユーザーがrebaseを希望する場合:
     - `git rebase origin/<base-branch>`
   - それ以外（デフォルトはmerge）:
     - `git merge origin/<base-branch>`

4. **コンフリクトファイルの特定**:
   - コンフリクト一覧: `git diff --name-only --diff-filter=U`
   - 各ファイルのコンフリクト領域を表示

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
   - rebaseの場合: `git rebase --continue`
   - mergeの場合、検出された言語でコミットメッセージを記述:
     - 英語: `merge: resolve conflicts with <base-branch>`
     - 日本語: `merge: <base-branch>とのコンフリクトを解消`

7. **変更をプッシュ**:
   - rebaseの場合: `git push --force-with-lease`
   - mergeの場合: `git push`
   - force push前にユーザーに警告（検出された言語で）

8. **結果を返す**（検出された言語で）:

## 英語フォーマット

```markdown
## Conflict Resolution Summary

### Resolved Files

| File            | Resolution    | Reasoning                     |
| --------------- | ------------- | ----------------------------- |
| path/to/file.ts | Combined both | Both changes were independent |

### Actions Taken

- Strategy used: merge / rebase
- Commits created: X
- Force push required: Yes / No
```

## 日本語フォーマット

```markdown
## コンフリクト解消サマリー

### 解消したファイル

| ファイル        | 解決方法   | 理由                         |
| --------------- | ---------- | ---------------------------- |
| path/to/file.ts | 両方を統合 | 両方の変更が独立していたため |

### 実行したアクション

- 使用した戦略: merge / rebase
- 作成したコミット: X件
- Force pushが必要: はい / いいえ
```

## 注意事項

- 複雑なコンフリクト（大きなファイル、アーキテクチャの変更）の場合は、コンフリクトを表示してユーザーに判断を求める
- 安全のため、`--force` ではなく常に `--force-with-lease` を使用する
- rebaseでコンフリクトが多発する場合は、中止してmergeの使用を検討する
- 解消後、問題がないことを確認するためにテストの実行を提案する
