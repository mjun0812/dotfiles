#!/usr/bin/env zsh

set -euo pipefail

if [[ ${RTK_DISABLED:-} == 1 ]]; then
    exit 0
fi

if ! command -v jq >/dev/null 2>&1 || ! command -v rtk >/dev/null 2>&1; then
    exit 0
fi

payload=$(cat) || exit 0
if ! command=$(print -rn -- "$payload" | jq -er 'select(.tool_name == "Bash") | .tool_input.command // empty' 2>/dev/null); then
    exit 0
fi

[[ -n $command ]] || exit 0

if ! rewritten=$(rtk rewrite "$command" 2>/dev/null); then
    exit 0
fi

if [[ -z $rewritten || $rewritten == "$command" ]]; then
    exit 0
fi

jq -cn --arg command "$rewritten" '{
    hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "allow",
        updatedInput: { command: $command }
    }
}'
