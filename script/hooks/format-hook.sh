#!/usr/bin/env zsh
# agentが編集したファイルに、formatterと自動修正だけをかけるPostToolUse hook。
# 自動で直らないlintエラーはagentへ返さない。
#
# 編集されたファイルの受け取り方:
#   Claude Code (Edit|Write): tool_input.file_path
#   Codex (apply_patch):      tool_input.command のpatch本文にある "*** Update File: <path>" などの行
#
# formatterが無い・失敗した場合もagentを止めないよう、常にexit 0で終える。

set -u

command -v jq >/dev/null 2>&1 || exit 0

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

# 以降のformatterの出力はagentに見せない
exec >/dev/null 2>&1

for file in "${files[@]}"; do
    # apply_patchのパスはセッションのcwdからの相対パスのことがある
    [[ $file == /* ]] || file="$cwd/$file"
    # 削除したファイルや移動元のパスは存在しないので飛ばす
    [[ -f $file ]] || continue

    # styluaは作業ディレクトリから上に向かって設定を探すため、ファイルの場所へ移動する
    cd "${file%/*}" || continue

    case $file in
    *.py)
        # F401 (未使用import) は直さない。agentはimportを先に書き、使う側を後の編集で書くことがあるため
        # --force-exclude: 明示したパスにもプロジェクトのexclude設定を適用する
        ruff check --fix --unfixable F401 --force-exclude --quiet "$file"
        ruff format --force-exclude --quiet "$file"
        ;;
    *.md)
        oxfmt "$file"
        ;;
    *.sh | *.bash | *.zsh)
        shfmt -w "$file"
        ;;
    *.lua)
        stylua -s "$file"
        ;;
    esac
done

exit 0
