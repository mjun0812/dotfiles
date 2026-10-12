#!/usr/bin/env zsh
# .ipynb を書き換えるapply_patchを拒否するCodexのPreToolUse hook。
# Claude Codeでは settings.json のdeny (Edit(//**/*.ipynb)) が同じ制限をかけている。

set -u

command -v jq >/dev/null 2>&1 || exit 0

patch=$(jq -r '.tool_input.command // ""')
grep -qE '^\*\*\* (Add File|Update File|Move to): .*\.ipynb$' <<<"$patch" || exit 0

jq -n '{
    hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ".ipynbはraw JSONとして編集しないこと。Jupytextのpaired .pyがあればそちらを編集し、cell単位の操作にはnb-cliを使うこと。"
    }
}'
exit 0
