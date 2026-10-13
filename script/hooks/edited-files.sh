#!/usr/bin/env zsh
# PostToolUse hookの入力JSON (stdin) から、agentが編集して現存するファイルの絶対パスを1行ずつ出力する。
#
# 編集されたファイルの受け取り方:
#   Claude Code (Edit|Write): tool_input.file_path
#   Codex (apply_patch|Bash): tool_input.command のpatch本文にある "*** Update File: <path>" などの行
#                             (shellのheredocでapply_patchを実行するとBashとして届き、commandにpatch本文が含まれる)

set -u

input=$(cat)
cwd=$(jq -r '.cwd // ""' <<<"$input")
file_path=$(jq -r '.tool_input.file_path // ""' <<<"$input")

files=()
if [[ -n $file_path ]]; then
    # Claude Code
    files=("$file_path")
else
    # Codex: patchのファイル見出しからパスを取り出す ("Move to" は移動後のパス)
    patch=$(jq -r '.tool_input.command // ""' <<<"$input")
    while IFS= read -r patched_file; do
        files+=("$patched_file")
    done < <(sed -nE 's/^\*\*\* (Add File|Update File|Move to): //p' <<<"$patch")
fi

for file in "${files[@]}"; do
    # apply_patchのパスはセッションのcwdからの相対パスのことがある
    [[ $file == /* ]] || file="$cwd/$file"
    # 削除したファイルや移動元のパスは存在しないので飛ばす
    [[ -f $file ]] && print -r -- "$file"
done
exit 0
