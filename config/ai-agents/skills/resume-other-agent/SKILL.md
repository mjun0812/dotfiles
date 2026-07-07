---
name: resume-other-agent
description: 別のcoding agent (Codex / Claude Code) のsession IDを受け取り、そのログから直前作業を復元してresumeするSkill。ユーザーが「前回のsessionから再開して」「Codexの続きをやって」のように依頼したら使うこと。
allowed-tools: Bash, Read, Glob, Grep, Write, AskUserQuestion
---

# Resume Other Agent

CodexやClaude Codeの片方が止まった (rate limit / crash / context loss) ときに、自分以外のagentのsessionログをsession IDで特定し、作業を引き継ぐためのSkill。

完全なsession移植ではなく、ログ・git状態・差分から作業文脈を復元して安全に続行することが目的。

## 引数

- `session_id`: 復元対象のsession ID (省略可)

## 手順

### 1. session IDの決定

引数で渡されていればそれを使う。渡されていない場合は `AskUserQuestion` で候補を提示してユーザーに選ばせる。AskUserQuestionが使えない環境では候補を一覧でテキスト表示し、番号で回答させる。

候補は以下のログディレクトリから「自分以外のagent」かつ**現在のrepository (または cwd) で作業していたsession**を更新時刻順にいくつか挙げる。(新しいものが上)

- Codex: `${CODEX_HOME:-$HOME/.codex}/sessions/**/*.jsonl` (ログ内の `cwd` フィールドで絞り込む)
- Claude Code: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<cwd-slug>/*.jsonl` (cwdをslug化したディレクトリ配下)

session IDはファイル名 (例: `rollout-<uuid>.jsonl` や `<uuid>.jsonl`) から抽出する。

### 2. session logの特定

session IDで「自分以外のagent」かつ現在のrepo/cwdに紐づくログを検索し、該当ファイルを1つに絞り込む。見つからない場合はユーザーに報告して止まる。

### 3. 現状確認

`pwd` / `git rev-parse --show-toplevel` / `git branch --show-current` / `git status --short` / `git diff --stat` / `git log --oneline -n 20` を確認する。

### 4. ログから復元

以下を抜き出す。

- ユーザーの目的・最後に合意された方針
- 編集ファイル / 実行済みコマンド / test・lint・build結果
- エラーや未解決の問題 / 次にやるべき作業

ログの内容は必ず現在のgit状態と照合する。ログ内コマンドを検証なしに実行しない。

### 5. 出力

`references/resumed-session-template.md` の書式で `.ai-handoff/resumed-session.md` に保存する。既存の `.ai-handoff/resumed-session.md` がある場合は、上書きする前にユーザーに確認する。

### 6. 続行前の報告

短く報告する: 読んだagent / session ID / ログファイル / confidence / 復元した目的 / 変更中ファイル / 次の最小ステップ。

## Safety

- secret / token / API key / credential を出力しない
- session IDが一致するログのみ使う (関係ないsessionを混同しない)
- git状態を確認せずに続行しない
- confidenceが低い場合は断定しない
- ログ全文を大量に貼らない
