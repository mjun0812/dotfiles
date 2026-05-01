---
name: git-commit-push
description: git-commit skillでcommitした後、現在のbranchをリモートへpushまで行うSkill。commit & pushを一括実行する際に使用する。
allowed-tools: Skill(git-commit), Bash(git status:*), Bash(git branch:*), Bash(git log:*), Bash(git push:*), Bash(git rev-parse:*), Bash(git ls-remote:*)
---

# git commit & push

`git-commit` skillでコミットを作成したのち、現在のbranchをリモートへpushします。
commitメッセージ生成のロジックは `git-commit` skillに委譲するため、本Skillでは複製しません。

## 引数

- `language`: コミットメッセージの言語（例: "ja", "en"）。デフォルト: "English"
  - 受け取った値はそのまま `git-commit` skillに渡してください。

## タスク

### 1. 事前チェック

1. 変更の有無を確認: `git status`
   - commit対象の変更（staged/unstaged/untracked）が一切ない場合は中止してください。

### 2. commit フェーズ（git-commit skill に委譲）

1. Skillツールで `git-commit` skillを呼び出してください。`language` 引数はそのまま転送します。
2. `git-commit` skillが返したコミットメッセージは後段の出力で再利用するため保持してください。
3. `git-commit` skillが失敗した場合は、そこで処理を打ち切り、エラー内容をユーザーに返してください（pushは行わない）。

### 3. push フェーズ

1. 現在のbranchを再取得: `git branch --show-current`
2. upstream の有無を確認: `git rev-parse --abbrev-ref @{upstream} 2>/dev/null`
3. 状況に応じて push を実行:
   - **upstream 未設定**: `git push -u origin <current-branch>`
   - **upstream 設定済み・履歴が線形**: `git push`
   - **diverge している（リモートに未取得のcommitがある）**: 自動で force push せず、`git push --force-with-lease` を提案してユーザーの確認を得てから実行してください。
4. push が失敗した場合は、エラー出力をそのままユーザーに提示し、`git pull --rebase` や手動対応など適切な次アクションを案内してください。

### 4. 結果の出力

以下を簡潔にまとめて出力してください。余計な説明は不要です。

- `git-commit` skill が生成したコミットメッセージ
- push 先（`origin/<branch>`）
- push 結果（成功 / スキップ / 失敗）
