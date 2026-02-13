---
name: squash
allowed-tools: Bash(git:*), Bash(gh:*)
argument-hint: [language] [--one | --auto] [--message <commit message>]
description: 現在のbranchのcommitをsquash・整理する。言語指定可能。
context: fork
---

# Squash Commits

現在のbranchのcommitをsquash・整理する。

## Arguments

- `language`: commitメッセージの言語（例: "ja", "en"）。デフォルト: "English"
- `--one` or `-1`: 全commitを1つにsquashする
- `--auto`: 論理単位で自動的にcommitをグループ化する
- `--message <msg>`: commitメッセージを指定（`--one` と併用）
- (none): commit分析を表示し、ユーザーに方針を確認する

## Context

- 現在のbranch: !`git branch --show-current`
- base branch: !`gh pr view --json baseRefName --jq .baseRefName 2>/dev/null || git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | grep -o '[^/]*$' || echo "main"`
- PRタイトル: !`gh pr view --json title --jq '.title' 2>/dev/null || echo "none"`

## Task

### 0. 事前チェック

1. **commitの存在確認**:
   - `git log --oneline origin/<base>..HEAD` でcommit数を確認
   - 0件の場合: 「squash対象のcommitがありません」と報告して終了
   - 1件の場合: 「commitが1件のみのためsquash不要です」と報告して終了
2. **作業ディレクトリの状態確認**:
   - `git status --porcelain` で未commitの変更を確認
   - 変更がある場合: stashするか中止するかユーザーに確認
3. **リモートとの乖離チェック**:
   - `git log HEAD..origin/<current-branch> --oneline` でリモートにのみ存在するcommitを確認
   - リモート側に進んでいるcommitがある場合: force pushでデータが失われる可能性を警告し、続行するか確認

### 1. commit履歴の分析

- commit一覧を取得: `git log --format="%h %s" origin/<base>..HEAD`
- commitを分類:
  - Feature: `feat:`, `add:`
  - Fix: `fix:`, `bugfix:`
  - Refactor: `refactor:`, `chore:`
  - Style: `style:`, `format:`
  - Test: `test:`
  - Docs: `docs:`

### 2. squash方針の提案

以下の形式でユーザーに提案し、**AskUserQuestion Tool** で方針を選択してもらう（`--one` / `--auto` 指定時はスキップ）:

```markdown
## 現在のコミット (全X件)

| ハッシュ | タイプ | メッセージ             |
| -------- | ------ | ---------------------- |
| abc1234  | feat   | ユーザー認証を追加     |
| def5678  | fix    | 認証のtypoを修正       |
| ghi9012  | fix    | レビューコメントに対応 |
| jkl3456  | style  | コードをフォーマット   |

## 整理方法

### オプション1: 1つにまとめる (--one)

全コミット → `feat: Add user authentication`

### オプション2: 論理単位でグループ化 (--auto)

- `feat: Add user authentication` (abc1234, def5678, ghi9012)
- `style: Format code` (jkl3456)

### オプション3: 現状維持

変更なし
```

### 3. squashの実行

- **`--one` の場合**:
  1. `git reset --soft origin/<base>`
  2. `git commit` で1つのcommitにまとめる

- **`--auto` の場合**:
  1. 論理単位のグループを決定（ステップ1の分類結果を使用）
  2. `git reset --soft origin/<base>` で全commitを解除
  3. グループごとに段階的にcommit:
     - 各グループに属するファイルを `git add <files>` でステージング
     - グループ単位で `git commit`
  4. **同一ファイルに複数グループの変更が混在する場合**:
     - `git add -p <file>` でhunk単位のステージングを試みる
     - hunk分離が困難な場合は、該当ファイルを最も関連性の高いグループに含め、commitメッセージにその旨を記載する
     - フォールバック: グループ分離が全体的に困難な場合は `--one` 相当にフォールバックし、ユーザーに通知する

- **対話モードの場合**:
  - ステップ2で AskUserQuestion Tool を使って選択された方針に応じて上記いずれかを実行

### 4. commitメッセージの生成

- **`--message` 指定時**: 指定されたメッセージをそのまま使用
- **未指定時**: 以下のルールで生成:
  - `$ARGUMENTS` の `language` で指定された言語で記述（デフォルト: English）
  - Conventional Commits形式に従う:

  ```
  <type>: <primary change summary>

  - Detail 1
  - Detail 2
  - Detail 3
  ```

### 5. force pushと確認

1. ユーザーに警告: 「force pushが必要です。続行しますか？」
2. 承認された場合: `git push --force-with-lease`
3. `--force-with-lease` が失敗した場合:
   - エラー内容を表示し、リモートが更新されている可能性を説明
   - `git fetch` で最新を取得してから再度確認することを提案
   - **`--force` へのフォールバックは行わない**
4. 拒否された場合: 手動実行のコマンドを案内

### 6. 結果の表示

```markdown
## Squash完了

### 変更前

- X件のコミット

### 変更後

- Y件のコミット

### 新しいコミット

| ハッシュ | メッセージ               |
| -------- | ------------------------ |
| xyz7890  | feat: Add authentication |

### プッシュ

- origin/<branch>にforce pushしました
- CIが再実行されます
```

## Notes

- force pushには常に `--force-with-lease` を使用し、`--force` は使用しない
- rebaseでconflictが発生した場合は、ユーザーに解決手順を案内する
