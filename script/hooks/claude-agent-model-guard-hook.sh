#!/usr/bin/env zsh
# FableをSubAgentのmodelに明示した呼び出しを拒否するClaude CodeのPreToolUse hook (Agent)。
# modelを省略した呼び出しは、agent定義やメインの会話からmodelが決まるため検査できない。

set -u

command -v jq >/dev/null 2>&1 || exit 0

model=$(jq -r '.tool_input.model // ""')
# alias (fable) とmodel ID (claude-fable-5-1) の両方に一致させる
grep -qi 'fable' <<<"$model" || exit 0

jq -n --arg model "$model" '{
    hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("FableはSubAgentとして使用しないこと。タスクの性質に応じてhaiku・sonnet・opusから選び直す。指定値: model=" + $model)
    }
}'
exit 0
