#!/usr/bin/env zsh
# .ipynb を書き換えるapply_patchを拒否するCodexのPreToolUse hook (apply_patch|Bash)。
# shellのheredocでapply_patchを実行した場合はBashとして届くため、commandのpatch本文を同じように検査する。
# Claude Codeでは settings.json のdeny (Edit(//**/*.ipynb)、NotebookEdit) が同じ制限をかけている。

set -u

command -v jq >/dev/null 2>&1 || exit 0

patch=$(jq -r '.tool_input.command // ""')
grep -qE '^\*\*\* (Add File|Update File|Move to): .*\.ipynb$' <<<"$patch" || exit 0

jq -n '{
    hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ".ipynbはraw JSONとして編集しないこと。nb-cli (nbコマンド) で編集し、nb-cliで行えない操作にだけJupytextを使うこと。"
    }
}'
exit 0
