#!/usr/bin/env zsh
# Claude Codeのsettings.jsonのdenyに当たる制限を、CodexでかけるPreToolUse hook (apply_patch|Bash)。
#   - ~/.zshrc.localの名前を含むshellコマンドを拒否する。tokenやAPIキーを置くので、中身を会話へ出さない。
#     Claude CodeではdenyのRead(~/.zshrc.local) とBash(*zshrc.local*) が同じ制限をかけている。
#     apply_patchはpatch本文がこの名前を含む文書の編集まで止めてしまうので対象にしない
#   - .ipynbを書き換えるpatchを拒否する。Claude CodeではdenyのEdit(//**/*.ipynb)、NotebookEditが同じ制限をかけている
#   - shellのheredocで実行するapply_patchコマンドを拒否し、apply_patchツールを使わせる。
#     編集対象に応じたルールを渡すcodex-rules-hook.shはapply_patchにだけ登録しているため
# shell経由のpatchはBashとして届き、tool_input.commandにpatch本文を含むコマンドが入る。

set -u

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
tool_name=$(jq -r '.tool_name // ""' <<<"$input")
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")

reason=""
if [[ $tool_name == Bash && $cmd == *zshrc.local* ]]; then
    reason="~/.zshrc.local にはtokenやAPIキーがあるので、読まないこと。内容が必要なら、ユーザーに必要な部分だけを尋ねること。"
elif grep -qE '^\*\*\* (Add File|Update File|Move to): .*\.ipynb$' <<<"$cmd"; then
    reason=".ipynbはraw JSONとして編集しないこと。nb-cli (nbコマンド) で編集し、nb-cliで行えない操作にだけJupytextを使うこと。"
elif [[ $tool_name == Bash ]] && grep -qE '(^|[;&|])[[:space:]]*(apply_patch|applypatch)([[:space:]]|$)' <<<"$cmd"; then
    reason="編集対象に応じたルールを受け取るため、apply_patchツールを直接使うこと。"
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
