---
name: issue-resolve-with-grill
description: GitHub issueを起点に、実装前にgrill-self skillで設計の分岐点を徹底的に自己解決し、その意思決定ログに基づいてgithub-issue-resolve skillで「worktree作成 → 実装 → PR作成」まで一気通貫で実行するオーケストレーションSkill。ユーザーが「設計を詰めてから#Nを解決して」「grillしてからissueを実装して」「issue-resolve-with-grillして」のように依頼した際に使用する。単独でgrillのみ／issue解決のみを求められた場合は使わない。
allowed-tools: Skill, Bash(gh:*), Bash(git:*), Bash(jq:*)
---

# Issue Resolve with Grill

「設計の自己grill → issue解決」を直列実行する薄いオーケストレーションSkill。
**詳細ロジックは委譲先のSkillに従う**。本Skillでは順序制御と引き継ぎのみを行い、grill手順や実装・PR作成手順を独自に再実装しない。

- 設計分岐の自己解決・意思決定ログの生成 → `grill-self`
- 調査・worktree作成・実装・PR作成・クリーンアップ → `github-issue-resolve`

## Arguments

- `issue` (必須): 解決対象のissue番号。先頭の `#` は省略可（例: `123` または `#123`）
- `language` (任意): issueコメント・PR本文の言語（例: `ja`, `en`）。デフォルトは `ja`。`github-issue-resolve` にそのまま転送する
- `--draft` (任意): draft PRとして作成（`github-issue-resolve` に転送）

## Task

### Phase 1: 対象issueの取得

grill対象を確定するため、issueの内容を取得する:

```bash
gh issue view <number> --json number,title,state,body,labels,comments,url
```

- issueが `state: CLOSED` の場合は中止し、「issue #N は既にclosedです」と通知する（grillを無駄に走らせない）。

### Phase 2: 設計のgrill（grill-self に委譲）

1. Skillツールで `grill-self` Skillを起動する。対象として「issue #N を解決するための実装計画」を渡し、issueのタイトル・本文・コメントの要点を添える。
2. `grill-self` の通常フロー（分岐点ごとに調査 → 推奨案 → 反論 → 採択）にそのまま従い、意思決定ログ（論点 / 決定 / 根拠 / 確信度）を得る。
3. 意思決定ログは Phase 3 への引き継ぎ情報として保持する。

### Phase 3: issue解決（github-issue-resolve に委譲）

1. Skillツールで `github-issue-resolve` Skillを起動し、`issue` / `language` / `--draft` をそのまま転送する。
2. その際、Phase 2 の意思決定ログを実装方針として引数に添え、`github-issue-resolve` 側の「実装方針を決める」工程ではログの決定に従うよう指示する。grillで解決済みの論点を再検討させない。
3. 確信度 low の「要確認」項目も判断材料としてそのまま引き継ぐ。

### Phase 4: 結果の表示

以下を簡潔にまとめて出力する:

- **Issue / Branch / PR / 変更概要**: `github-issue-resolve` の出力をそのまま使う
- **意思決定ログのサマリ**: 決定した論点の数と、確信度 low の「要確認」項目の一覧（あれば）。ユーザーがPRレビュー時に重点的に見るべき箇所として提示する

## ガードレール

- Phase 2（grill-self）が中止・失敗した場合は Phase 3 を実行しない。
- 委譲先Skillの責務（worktree管理、commit、PR本文生成、クリーンアップ、closed issueの再チェック）は本Skillで複製しない。
- 意思決定ログの内容を本Skillで上書き・再判断しない。覆すべき決定があってもPhase 3で勝手に変えず、「要確認」として最終出力に含める。
