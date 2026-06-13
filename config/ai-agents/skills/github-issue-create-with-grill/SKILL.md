---
name: github-issue-create-with-grill
description: 新規GitHub issueを作る前に、grill-self skillで方針・設計の分岐点を徹底的に自己解決し、その意思決定ログを本文に埋め込んだ上でgithub-issue-create skillでissueを起票するオーケストレーションSkill。ユーザーが「方針を詰めてからissue化して」「grillしてからissueを作って」「github-issue-create-with-grillして」のように依頼した際に使用する。単独でgrillのみ／issue作成のみを求められた場合は使わない。
allowed-tools: Skill, Bash(gh:*), Bash(git:*)
---

# Create GitHub Issue with Grill

「方針の自己grill → issue作成」を直列実行する薄いオーケストレーションSkill。
**詳細ロジックは委譲先のSkillに従う**。本Skillでは順序制御と引き継ぎのみを行い、grill手順やテンプレート選択・ラベル判定・起票手順を独自に再実装しない。

- 方針・設計分岐の自己解決・意思決定ログの生成 → `grill-self`
- テンプレート選択・タイトル/本文生成・ラベル付与・起票 → `github-issue-create`

## Arguments

- `topic` (任意): 起票したいissueの概要を表す自由テキスト。省略時はユーザーに自由入力で求める
- `language` (任意): issueのタイトル・本文の言語（例: `ja`, `en`）。デフォルトは `en`。`github-issue-create` にそのまま転送する
- `--label <name>` (任意、複数指定可): ラベル追加指定。`github-issue-create` にそのまま転送する
- `--assignee <username>` (任意、複数指定可): 担当者指定。`github-issue-create` にそのまま転送する

## Task

### Phase 1: 起票対象の取得

1. 引数 `topic` が渡されていればそれを「下書き素材」として保持する。
2. 渡されていなければ、ユーザーに以下を提示して自由入力で受け取る:

   > 起票したいissueの概要を自由に記述してください。背景、目的、達成したいこと、判断に迷っている論点など、分かる範囲で構いません。1行でも構いません。

3. 受け取ったテキスト全体を「下書き素材」として Phase 2 に引き渡す。

### Phase 2: 方針のgrill（grill-self に委譲）

1. Skillツールで `grill-self` Skillを起動する。対象として「このissueで扱う方針・設計」を渡し、下書き素材の要点を添える。
2. `grill-self` の通常フロー（分岐点ごとに調査 → 推奨案 → 反論 → 採択）にそのまま従い、意思決定ログ（論点 / 決定 / 根拠 / 確信度）を得る。
3. 意思決定ログは Phase 3 への引き継ぎ情報として保持する。

### Phase 3: issue作成（github-issue-create に委譲）

1. Skillツールで `github-issue-create` Skillを起動する。`language` / `--label` / `--assignee` をそのまま転送する。
2. その際、Phase 1 の下書き素材に **Phase 2 の意思決定ログを追記したもの** を「下書き素材」として渡し、`github-issue-create` 側のテンプレート判定・本文生成にそのまま乗せる。grillで解決済みの論点を再検討させない。
3. `github-issue-create` の本文生成では、選択されたテンプレートのセクションに加えて、意思決定ログを以下の構造で挿入するよう指示する:
   - **Design Decisions / 設計上の決定事項**: 採択された決定を「論点 / 決定 / 根拠 / 確信度」の表で再掲
   - **Open Questions / 要確認事項**: 確信度 low の項目を箇条書きで再掲し、覆した場合の影響範囲を一言添える（存在しない場合はセクション自体を省略）
4. 確認・修正・起票は `github-issue-create` の通常フローに委ねる。本Skillで本文を勝手に上書きしない。

### Phase 4: 結果の表示

以下を簡潔にまとめて出力する:

- **Issue URL / タイトル / 付与ラベル / 担当者**: `github-issue-create` の出力をそのまま使う
- **意思決定ログのサマリ**: 決定した論点の数と、確信度 low の「要確認」項目の一覧（あれば）。起票後の議論で重点的に詰めるべき箇所として提示する

## ガードレール

- Phase 2（grill-self）が中止・失敗した場合は Phase 3 を実行しない。
- 委譲先Skillの責務（テンプレート選択、ラベル自動判定、起票、確認フロー）は本Skillで複製しない。
- 意思決定ログの内容を本Skillで上書き・再判断しない。覆すべき決定があってもPhase 3で勝手に変えず、「要確認」として本文と最終出力に含める。
