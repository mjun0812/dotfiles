---
name: git-commit-push
description: git-commit skillでcommitした後、現在のbranchをリモートへpushまで行うSkill。commit & pushを一括実行する際に使用する。
allowed-tools: Skill(git-commit), Bash(git branch:*), Bash(git remote:*), Bash(git fetch:*), Bash(git rev-parse:*), Bash(git rev-list:*), Bash(git push:*)
---

# git commit & push

`git-commit` skillでコミットを作成したのち、現在のbranchをリモートへpushします。
commitメッセージ生成のロジックは `git-commit` skillに委譲するため、本Skillでは複製しません。

## 引数

- `language`: コミットメッセージの言語（例: "ja", "en"）。デフォルト: "ja"
  - 受け取った値はそのまま `git-commit` skillに渡してください。

## タスク

### 1. commit(git-commit skill に委譲)

Skillツールで `git-commit` skillを呼び出してください。`language` 引数はそのまま転送します。

- `git-commit`skillが返したコミットメッセージは後段の出力で再利用するため保持してください。
- `git-commit`skillが失敗した場合は、そこで処理を打ち切り、エラー内容をユーザーに返してください（pushは行わない）。

### 2. push

1. remoteを決定: `git remote` の出力が1つならそれを使用。複数なら `origin` を優先（無ければ選択を求める）。0個なら中止。
2. upstream未設定なら `git push -u <remote> $(git branch --show-current)`。設定済みなら `git fetch <remote>` 後に `git rev-list --left-right --count @{upstream}...HEAD` でdivergeを確認し、behind=0なら `git push`、behind>0なら `git push --force-with-lease` をユーザー確認の上で実行。
3. push失敗時はSSH ↔ HTTPS変換（`git@github.com:user/repo.git` ↔ `https://github.com/user/repo.git`）したURLを直指定で再試行。それも失敗したら両方のエラーを提示し、`git pull --rebase` 等を案内。

### 3. 結果の出力

以下を簡潔にまとめて出力してください。余計な説明は不要です。

- `git-commit` skill が生成したコミットメッセージ（pushのみの場合は省略し「commitなし」と記載）
- commit hash（`git rev-parse --short HEAD` の結果。push専用モードの場合は対象先頭commitのhash）
- push 先（`<remote>/<branch>`）
- push 結果（成功 / スキップ / 失敗）
