#!/usr/bin/env zsh
# apply_patchの対象と経路を検査するCodexのPreToolUse hook (apply_patch|Bash)。
#   - .ipynb を書き換えるpatchを拒否する。Claude Codeでは settings.json のdeny (Edit(//**/*.ipynb)、NotebookEdit) が同じ制限をかけている
#   - shellのheredocで実行するapply_patchコマンドを拒否し、apply_patchツールを使わせる。
#     shell経由のpatchではPostToolUseが発火せず、format-hook.sh が動かないため
# shell経由のpatchはBashとして届き、tool_input.command にpatch本文を含むコマンドが入る。

set -u

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
tool_name=$(jq -r '.tool_name // ""' <<<"$input")
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")

reason=""
if grep -qE '^\*\*\* (Add File|Update File|Move to): .*\.ipynb$' <<<"$cmd"; then
    reason=".ipynbはraw JSONとして編集しないこと。nb-cli (nbコマンド) で編集し、nb-cliで行えない操作にだけJupytextを使うこと。"
elif [[ $tool_name == Bash ]] && grep -qE '(^|[;&|])[[:space:]]*(apply_patch|applypatch)([[:space:]]|$)' <<<"$cmd"; then
    reason="shellのapply_patchコマンドではなく、apply_patchツールを直接使うこと。shell経由のpatchにはformat hookが動かないため。"
fi
[[ -n $reason ]] || exit 0

jq -n --arg reason "$reason" '{
    hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
    }
}'
exit 0
