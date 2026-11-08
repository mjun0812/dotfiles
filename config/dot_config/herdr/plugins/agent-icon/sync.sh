#!/usr/bin/env zsh
set -euo pipefail

# claudeとcodexのpaneの表示名を、Nerd Fontのアイコン付きの名前にする。
# アイコンはNerd Fonts 3.5のcodicons (cod-claude, cod-openai)。codex専用の
# アイコンは無いのでOpenAIのロゴを使う。--agentで種類を指定しておくと、
# paneのagentが別の種類に変わった時点で表示名が元に戻る。

herdr_bin="${HERDR_BIN_PATH:-herdr}"
typeset -A icons=(
    claude $''
    codex $''
)

"$herdr_bin" pane list |
    jq -r '.result.panes[] | select(.agent == "claude" or .agent == "codex") | "\(.pane_id)\u001f\(.agent)"' |
    while IFS=$'\037' read -r pane_id agent; do
        "$herdr_bin" pane report-metadata "$pane_id" --source agent-icon --agent "$agent" --display-agent "${icons[$agent]} $agent" >/dev/null
    done
