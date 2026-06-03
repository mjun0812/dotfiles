---
name: git-commit-push
description: git-commit skillでcommitした後、現在のbranchをリモートへpushまで行うSkill。commit & pushを一括実行する際に使用する。
allowed-tools: Skill(git-commit), Bash(git status:*), Bash(git branch:*), Bash(git log:*), Bash(git push:*), Bash(git rev-parse:*), Bash(git rev-list:*), Bash(git ls-remote:*), Bash(git remote:*), Bash(git fetch:*)
---

# git commit & push

`git-commit` skillでコミットを作成したのち、現在のbranchをリモートへpushします。
commitメッセージ生成のロジックは `git-commit` skillに委譲するため、本Skillでは複製しません。

## 引数

- `language`: コミットメッセージの言語（例: "ja", "en"）。デフォルト: "ja"
  - 受け取った値はそのまま `git-commit` skillに渡してください。

## タスク

### 1. 事前チェック

1. 変更の有無を確認: `git status`
2. commit対象の変更（staged/unstaged/untracked）の有無で実行モードを決定する:
   - **変更あり**: 通常モード。commit フェーズと push フェーズを順に実行する。
   - **変更なし**: 未pushの commit があるか確認し、push 単体実行の可否を判定する。
     - upstream 設定済み: `git rev-list --count @{upstream}..HEAD` の結果が `> 0` なら **push専用モード**（commitフェーズをスキップして push フェーズへ）。
     - upstream 未設定: ローカルbranchに少なくとも1つのcommitがあれば **push専用モード**（初回push扱い）。
     - 上記いずれにも該当しない（変更なし & 未pushもなし）: 中止し、その旨をユーザーに伝える。

### 2. commit フェーズ（git-commit skill に委譲）

> push専用モードの場合、本フェーズはスキップして「3. push フェーズ」へ進んでください。

1. Skillツールで `git-commit` skillを呼び出してください。`language` 引数はそのまま転送します。
2. `git-commit` skillが返したコミットメッセージは後段の出力で再利用するため保持してください。
3. `git-commit` skillが失敗した場合は、そこで処理を打ち切り、エラー内容をユーザーに返してください（pushは行わない）。

### 3. push フェーズ

1. 現在のbranchを取得: `git branch --show-current`
2. push先のremoteを決定: `git remote`
   - remoteが1つだけならそれを使用してください。
   - 複数ある場合は `origin` があれば優先、無ければユーザーに選択を求めてください。
   - 0個の場合は中止し、その旨を伝えてください。
3. upstream の有無を確認: `git rev-parse --abbrev-ref @{upstream} 2>/dev/null`
4. upstream が設定済みの場合は最新状態を取得: `git fetch <remote>`
5. diverge を検出: `git rev-list --left-right --count @{upstream}...HEAD`
   - 出力は `<behind>\t<ahead>` 形式。`behind > 0` ならリモートに未取得のcommitあり（diverge）。
6. 状況に応じて push を実行:
   - **upstream 未設定**: `git push -u <remote> <current-branch>`
   - **upstream 設定済み・behind = 0**: `git push`
   - **diverge（behind > 0）**: 自動で force push せず、`git push --force-with-lease` を提案してユーザーの確認を得てから実行してください。
7. push が失敗した場合は、SSH ↔ HTTPS のフォールバックを試みてください:
   1. 現在の remote URL を取得: `git remote get-url <remote>`
   2. URL の種別を判定する:
      - SSH形式: `git@github.com:user/repo.git` または `ssh://git@github.com/user/repo.git`
      - HTTPS形式: `https://github.com/user/repo.git`
   3. 現在が SSH なら HTTPS URL に変換し、HTTPS なら SSH URL に変換する:
      - SSH → HTTPS: `git@github.com:user/repo.git` → `https://github.com/user/repo.git`
      - HTTPS → SSH: `https://github.com/user/repo.git` → `git@github.com:user/repo.git`
   4. 変換した URL を使って push を再試行する（remote URLを恒久変更せず、URL直指定で実行）:
      - upstream 未設定の場合: `git push -u <converted-url> <current-branch>`
      - upstream 設定済みの場合: `git push <converted-url> HEAD:<current-branch>`
   5. フォールバックも失敗した場合は、両方のエラー出力をユーザーに提示し、`git pull --rebase` や手動対応など適切な次アクションを案内してください。

### 4. 結果の出力

以下を簡潔にまとめて出力してください。余計な説明は不要です。

- 実行モード（通常モード / push専用モード）
- `git-commit` skill が生成したコミットメッセージ（push専用モードの場合は省略し「commitなし（push専用）」と記載）
- commit hash（`git rev-parse --short HEAD` の結果。push専用モードの場合は対象先頭commitのhash）
- push 先（`<remote>/<branch>`）
- push 結果（成功 / スキップ / 失敗）
