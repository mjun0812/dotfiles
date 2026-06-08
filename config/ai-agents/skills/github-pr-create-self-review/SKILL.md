---
name: github-pr-create-self-review
description: Pull Requestを作成した直後にそのままセルフレビューまで一気通貫で実行するSkill。github-pr-create と github-pr-review を順に呼び出して「PR作成 → セルフレビュー投稿」をワンショットで完結させる。ユーザーが「PR作ってからセルフレビューも」「PR上げてレビューまでして」「pr create と self review を一緒に」のように複合タスクを口にしたら必ずこのSkillを使うこと。単独でPR作成のみ／レビューのみを求められた場合は使わない。
allowed-tools: Skill, Bash(gh:*), Bash(git:*), Bash(jq:*)
---

# Pull Request Create + Self Review

PR作成とセルフレビューを直列実行するための薄いオーケストレーションSkill。
**詳細ロジックは委譲先のSkillに従う**。本Skillでは順序制御と引き渡しのみを行い、PR作成手順やレビュー手順を独自に再実装しない。

## Arguments

- `language`: PR本文・レビュー本文の言語（例: "ja", "en"）。`github-pr-create` と `github-pr-review` の双方にそのまま転送する
- `--draft`: draft PR として作成（`github-pr-create` に転送）
- `--reviewer <username>`: reviewerを追加（`github-pr-create` に転送、複数指定可）
- `--label <name>`: labelを追加（`github-pr-create` に転送、複数指定可）

引数はユーザー入力をそのまま `github-pr-create` に渡せばよい。本Skillでパースし直す必要はない。

## Task

### Phase 1: PR作成（github-pr-create に委譲）

1. Skillツールで `github-pr-create` Skillを起動する
2. 受け取った引数（`language` / `--draft` / `--reviewer` / `--label`）をそのまま転送する
3. 完了状態を確認し、以下のいずれかなら Phase 2 に進む:
   - 新規PR作成に成功
   - 既存PRが更新された
   - 既存PRに対してpushのみ実行された
4. エラー・中止の場合は本Skillも中止し、理由を伝える（レビューは行わない）

### Phase 2: 対象PRの特定

`github-pr-create` の出力にPR番号やURLが含まれているはずだが、確実を期すため再取得する:

```bash
gh pr view --json number,url --jq '{number: .number, url: .url}'
```

PRが取得できない場合（直前にcloseされた等の例外ケース）は中止する。

### Phase 3: セルフレビュー（github-pr-review に委譲）

1. Skillツールで `github-pr-review` Skillを起動する
2. Phase 2 で取得した **PR番号を引数として明示的に渡す**（current branch依存にせず、Phase 1で扱ったPRと同じものをレビュー対象に固定するため）
3. `github-pr-review` 内の通常フロー（5レビュアー並列実行 → 統合レポート生成 → GitHub投稿確認）にそのまま従う

### Phase 4: 結果の表示

以下を簡潔にまとめて出力する:

- **PR**: 作成または更新したPRのURL（Phase 1 の結果）
- **Review verdict**: 投稿したセルフレビューの判定（`APPROVE` / `REQUEST_CHANGES`）。投稿をスキップした場合は `not posted`。`github-pr-review` がself reviewモードでGitHub APIへの `event` を `COMMENT` に変換した場合でも、レポート上の Verdict 表記はこの2択のいずれかになる

## ガードレール

- 委譲先Skillの責務（commit品質チェック、diff取得、inline comments投稿、既存レビューのdismissなど）は本Skillで複製しない
- 同一PRに既存のセルフレビューがある場合の扱いは `github-pr-review` の判断に従う
- セルフレビューの投稿可否は最終的にユーザー確認に委ねる
- Phase 1 が失敗した場合に Phase 3 を実行しない（無関係なPRをレビューするのを防ぐため）
