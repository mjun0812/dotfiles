#!/usr/bin/env zsh
# zshの特殊変数への代入を止め、単純なBash用のreadをzsh用に直す。

set -u

command -v jq >/dev/null 2>&1 || exit 0
command -v shfmt >/dev/null 2>&1 || exit 0

input=$(cat)
# コマンド置換で入力の末尾の改行が消えないようにする。
cmd=$(jq -r 'select(.tool_name == "Bash") | (.tool_input.command // "") + "."' <<<"$input") || exit 0
cmd=${cmd%.}
[[ -n $cmd ]] || exit 0

tree=$(shfmt -ln zsh --to-json 2>/dev/null <<<"$cmd") || exit 0
issues=$(jq -r '
    .. | objects
        | if (.Type == "WordIter" and .Name.Value == "path")
            or any(.Assigns[]?; .Name.Value == "path")
            or (.Type == "DeclClause" and any(.Args[]?; .Name.Value == "path"))
        then "path"
        elif .Type == "CallExpr" then
            (.Args // [] | map(.Parts
                | if length == 1 then
                    .[0]
                    | if .Type == "DblQuoted" and (.Parts | length) == 1 then .Parts[0] else . end
                    | if .Type == "Lit" or .Type == "SglQuoted" then .Value else "" end
                  else "" end
            )) as $words
            | (if $words[0] == "builtin" or $words[0] == "command" then $words[1:] else $words end) as $args
            | if $args[0] == "mapfile" or $args[0] == "readarray" then "line_array"
              elif $args[0] == "read" then
                  # Stop at the first argument that is not a known flag without a value.
                  "rszpqAclneE" as $flags
                  | first(range(1; $args | length) | select($args[.] | test("^-[\($flags)]+$") | not)) as $option
                  | $args[$option] as $flag
                  | select($flag | test("^-[\($flags)]*a[\($flags)a]*$"))
                  | .Args[$option] as $word
                  | if $words[0] == "read"
                      and ($args[1:$option] == [] or ($args[1:$option] == ["-r"] and $flag == "-a"))
                      and ($flag | test("^-(a|ar|ra)$"))
                      and ($args | length) == $option + 2
                      and ($args[-1] | test("^[A-Za-z_][A-Za-z_0-9]*$"))
                      and $args[-1] != "path"
                      and $word.Parts[0].Type == "Lit"
                      and $word.End.Offset - $word.Pos.Offset == ($flag | length)
                    then "fix:\($word.Pos.Offset + ($flag | index("a")))"
                    else "read_array" end
              else empty end
        else empty end
' <<<"$tree") || exit 0

reason=''
rewritten=$cmd
# shfmtの位置はバイト単位なので、zshの文字列もバイト単位で切り出す。
unsetopt MULTIBYTE
for issue in ${(f)issues}; do
    case $issue in
    fix:*)
        offset=${issue#fix:}
        rewritten="${rewritten:0:$((offset))}A${rewritten:$((offset + 1))}"
        continue
        ;;
    path)
        reason='pathはzshでPATHと連動する特殊変数です。ループ変数や代入先にはfile_pathなど別の名前を使ってください。'
        ;;
    read_array)
        reason='zshのreadで入力を単語に分けて配列に入れるには、read -rA itemsを使ってください。区切り文字はIFSで指定できます。'
        ;;
    line_array)
        reason='zshでコマンドの出力を1行ずつ配列に入れるには、items=("${(@f)$(some_command)}")と書いてください。'
        ;;
    esac
    break
done

if [[ -z $reason ]]; then
    [[ $rewritten != "$cmd" ]] || exit 0
    # Codexでは書き換えにallowが必要。Claude Codeでは権限判定を委ねる。
    jq --arg cmd "$rewritten" --arg client "${1:-claude}" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            updatedInput: (.tool_input | .command = $cmd),
            additionalContext: "zshの配列入力に合わせてreadの-aを-Aに修正しました。"
        }
    } | if $client == "codex" then .hookSpecificOutput.permissionDecision = "allow" else . end' <<<"$input"
    exit $?
fi

jq -n --arg reason "$reason" '{
    hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
    }
}'
