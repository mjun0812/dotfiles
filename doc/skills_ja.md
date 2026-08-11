# Agent Skills

このドキュメントは、本リポジトリに同梱されているAI agent skillと、それらの依存関係について説明します。

Skillのソースは [`config/ai-agents/skills/`](../config/ai-agents/skills) 配下にあり、`install.sh` によって以下へsymlinkとしてデプロイされます。

- `~/.agents/skills/<skill>` — 共有skillディレクトリ
- `~/.claude/skills/<skill>` — Claude Code
- `~/.codex/skills/<skill>` — Codex
- `~/.gemini/antigravity-cli/skills/<skill>` — Antigravity CLI

`config/ai-agents/skills/` 配下のファイルを編集すると、symlink経由ですべてのagentに同時に反映されます。

## Skill一覧

各skillは `SKILL.md` を含むディレクトリです。Agentはfront-matterの `description` を読んで、いつ使うかを判断します。

### Git

| Skill                                                                      | 用途                                                                                       |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| [`git-commit`](../config/ai-agents/skills/git-commit/SKILL.md)             | 現在の変更を適切な単位でstaging・commitする                                                |
| [`git-squash`](../config/ai-agents/skills/git-squash/SKILL.md)             | 現在のbranchのcommitをsquash・整理し、必要なら force-with-lease でpushする                 |
| [`git-fix-conflict`](../config/ai-agents/skills/git-fix-conflict/SKILL.md) | merge、rebase、cherry-pick、revert、apply、PR などで発生したコンフリクトを検出して解消する |
| [`self-review`](../config/ai-agents/skills/self-review/SKILL.md)           | 未commit変更または指定commitをsnapshot化し、独立した2つのFinderで敵対的にreviewする        |

### GitHub Issue

| Skill                                                                                | 用途                                                                                                                                                                                                                                            |
| ------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`github-issue-create`](../config/ai-agents/skills/github-issue-create/SKILL.md)     | ユーザーから情報を収集してGitHub Issueを作成する（`--local` でGitHubに起票せず `.mjun/issues/` へmarkdown保存）                                                                                                                                 |
| [`github-issue-discover`](../config/ai-agents/skills/github-issue-discover/SKILL.md) | リポジトリをスキャンしてissue化すべき事項を発見し、重複を除いた上で承認のもと一括起票する (`--auto` で承認を省略し、`--local` で `.mjun/issues/` へmarkdown保存)                                                                                |
| [`github-issue-update`](../config/ai-agents/skills/github-issue-update/SKILL.md)     | open issueを点検し、古い・解決済み・重複・陳腐化したissueをclose・追記・label変更する (`--local`で`.mjun/issues/`の設計docを同様に整理する)                                                                                                     |
| [`github-issue-polish`](../config/ai-agents/skills/github-issue-polish/SKILL.md)     | issueまたは設計doc (markdownパス) を「それだけで実装できる」状態まで磨き上げる: コードベース調査・設計判断・worktreeでのお試し実装                                                                                                              |
| [`github-issue-resolve`](../config/ai-agents/skills/github-issue-resolve/SKILL.md)   | 一気通貫: 指定issueまたは設計doc (markdownパス) の調査 → worktree作成 → 実装 → PR作成。実装はタスクごとにimplementer/reviewer SubAgentを構造化ハンドオフと上限付き差し戻しで回し、commitとPR作成は `git-commit` / `github-pr-create` に連結する |

### GitHub Pull Request

| Skill                                                                                        | 用途                                                                                                                              |
| -------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| [`github-pr-create`](../config/ai-agents/skills/github-pr-create/SKILL.md)                   | 現在のbranchからPull Requestを作成し、概要・背景、関連Issue、実装方針、変更内容、影響範囲、検証結果の6項目で本文を記述する        |
| [`github-pr-review`](../config/ai-agents/skills/github-pr-review/SKILL.md)                   | 並列reviewerで要修正の指摘とmergeをブロックすべき規約・品質の指摘を発見・検証し、以前のレビューを最新スナップショットへ置き換える |
| [`github-pr-fix`](../config/ai-agents/skills/github-pr-fix/SKILL.md)                         | PRの全問題(コンフリクト、CI失敗、レビューコメント)を専用worktree内で検出・修正する                                                |
| [`github-fix-ci`](../config/ai-agents/skills/github-fix-ci/SKILL.md)                         | CIのステータスを確認し、失敗を分析して修正を適用する                                                                              |
| [`github-resolve-pr-comment`](../config/ai-agents/skills/github-resolve-pr-comment/SKILL.md) | PRのレビューコメントを確認し、対応・返信する                                                                                      |

### Planning & Design

| Skill                                                                    | 用途                                                                                        |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------- |
| [`experiment-plan`](../config/ai-agents/skills/experiment-plan/SKILL.md) | 機械学習実験の未決事項を一つずつ確認し、検証可能な計画書を `.mjun/experiments/` へ保存する  |
| [`grill-me`](../config/ai-agents/skills/grill-me/SKILL.md)               | 計画・設計について、すべての意思決定分岐が解消されるまで1問ずつユーザーに対話的に問いかける |
| [`grill-self`](../config/ai-agents/skills/grill-self/SKILL.md)           | 自律grill: agentが自分で調査し各設計判断を解消した上で、最後に決定ログを提示する            |

### Docs & Notes

| Skill                                                      | 用途                                                                                                                                                                 |
| ---------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`doc-sync`](../config/ai-agents/skills/doc-sync/SKILL.md) | リポジトリ内のドキュメント（Markdown、docstring、OpenAPI、設定サンプル）を実装と差分比較し、乖離を更新する                                                           |
| [`md-note`](../config/ai-agents/skills/md-note/SKILL.md)   | 現在の会話の調査内容を、自己完結型の日本語Markdownファイルとして保存する                                                                                             |
| [`steering`](../config/ai-agents/skills/steering/SKILL.md) | `.mjun/steering/` をプロジェクトの永続メモリとして生成 (Bootstrap)・drift検出付きで追記更新 (Sync) する。コード内に証拠のあるドメインのcustom steeringも自動作成する |

### Japanese Writing

| Skill                                                                                | 用途                                                                                                         |
| ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| [`japanese-tech-writing`](../config/ai-agents/skills/japanese-tech-writing/SKILL.md) | 日本語の技術文書・書籍原稿を書く／推敲するときの文章規範（整形、パラグラフライティング、LLM 臭の排除など）   |
| [`stop-ai-slop-jp`](../config/ai-agents/skills/stop-ai-slop-jp/SKILL.md)             | AIで書いた日本語を人間が書いた文章に戻す編集規範（主体の不在、命題型H2、両論併記、リズムの均一さなどを直す） |

出典:

- `japanese-tech-writing` — [k16shikano/fd287c3133457c4fd8f5601d34aa817d](https://gist.github.com/k16shikano/fd287c3133457c4fd8f5601d34aa817d) を元にしている

### Cross-Agent Consultation & Delegation

これらはuser-invoked専用で、agentが自発的に起動することはありません。

デフォルトはread-onlyの相談モードで、ユーザーが作業の実行を明示的に依頼したときだけ編集権限付きの委譲モードで実行します。自分自身と同じCLIのskillは使いません。

| Skill                                                  | 用途                                                                                       |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------ |
| [`claude`](../config/ai-agents/skills/claude/SKILL.md) | Claude Code (`claude -p`) への相談 (read-only) と、編集権限付きの作業委譲                  |
| [`codex`](../config/ai-agents/skills/codex/SKILL.md)   | Codex (`codex exec`) への相談 (read-onlyサンドボックス) と、`workspace-write` での作業委譲 |

### Misc

| Skill                                                                          | 用途                                                                                                                          |
| ------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| [`agent-browser`](../config/ai-agents/skills/agent-browser/SKILL.md)           | `agent-browser` CLIによるブラウザ自動化 (upstreamのstubをvendor。使い方は `agent-browser skills get core` で実行時に読み込む) |
| [`resume-other-agent`](../config/ai-agents/skills/resume-other-agent/SKILL.md) | 別のcoding agent（Codex / Claude Code）をsession IDで指定し、直前のcontextを復元してresumeする                                |
| [`skill-review`](../config/ai-agents/skills/skill-review/SKILL.md)             | Agent skillの仕様適合性を検証し、周辺skillとの発動競合を含む観点ごとの判定をレポートする。評価のみで編集はしない              |
| [`wezterm-control`](../config/ai-agents/skills/wezterm-control/SKILL.md)       | weztermのpane/tab/windowを `wezterm cli` で操作する。分割・フォーカス・リサイズ・内容の読み取り・コマンド送信と結果検証       |

## Dependencies

以下のskillはagentの `Skill` tool経由で他のskillを呼び出します。矢印はcallerからcalleeへ向かいます。

```mermaid
graph LR
    git-squash -. on conflict .-> git-fix-conflict

    github-issue-resolve --> github-pr-create
    github-issue-resolve --> git-commit



    github-pr-fix --> git-fix-conflict
    github-pr-fix --> github-fix-ci
    github-pr-fix --> github-resolve-pr-comment
```

### Caller → callee 表

| Caller                 | Callee                                                           | タイミング                                          |
| ---------------------- | ---------------------------------------------------------------- | --------------------------------------------------- |
| `git-squash`           | `git-fix-conflict`                                               | squash中にコンフリクトが発生した場合のみ            |
| `github-issue-resolve` | `git-commit`, `github-pr-create`                                 | Phase 4でworktreeの変更をcommitし、最終的なPRを作成 |
| `github-pr-fix`        | `git-fix-conflict`, `github-fix-ci`, `github-resolve-pr-comment` | 対応する問題が検出された場合のみ各calleeを実行      |

### Standalone skills

以下のskillは他のskillへ委譲しません。

`agent-browser`, `claude`, `codex`, `doc-sync`, `experiment-plan`, `git-commit`, `git-fix-conflict`, `github-fix-ci`, `github-issue-create`, `github-issue-discover`, `github-issue-polish`, `github-issue-update`, `github-pr-create`, `github-pr-review`, `github-resolve-pr-comment`, `grill-me`, `grill-self`, `japanese-tech-writing`, `md-note`, `resume-other-agent`, `self-review`, `skill-review`, `steering`, `stop-ai-slop-jp`, `wezterm-control`.

## Conventions

- Skill名はkebab-caseで、ドメイン単位（`git-*`、`github-*`、いくつかの汎用skill）にスコープされます。
- Front matter（`name`、`description`、`allowed-tools`）はagentが読む契約です。`description` はskillが正しくトリガーされるよう十分に具体的に書き、本体から呼び出すsub-skillは `allowed-tools` に `Skill(<dep>)` として記載してください。
- `allowed-tools`などのクライアント固有fieldは未対応agentで無視される場合があります。指定する場合は対象クライアントの現行構文に従い、skillに必要なtoolとコマンド範囲だけを許可してください。
- 既存skillの挙動を拡張する場合は、ロジックを複製するのではなく `Skill` tool経由で元のskillを呼び出すことを優先してください。改善がすべてのagentに一箇所で行き渡ります。
