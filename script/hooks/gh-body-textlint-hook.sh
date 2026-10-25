#!/usr/bin/env zsh
# `gh pr|issue create|edit|comment` と `gh pr review` で送る本文にtextlintをかけるClaude Code・CodexのPreToolUse hook (Bash)。
# 指摘があれば一度だけ止めて書き直させる。同じ本文で再実行したら通すので、誤検知でも先へ進める。
# 本文の展開結果はhookから見えないため、`$(...)` や `--body-file -` で渡す本文は、ファイルに書いて --body-file で渡させる。
# commitメッセージやひと言のコメントのような短い本文は検査しない。
# textlint・jqが無い、textlintが失敗したときは止めない。

set -u

command -v jq >/dev/null 2>&1 || exit 0

DOTPATH=${0:A:h:h:h}
# この長さ未満の本文は検査しない (日本語でおよそ100文字)
min_bytes=300

input=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
[[ $cmd == *gh* && ($cmd == *pr* || $cmd == *issue*) && $cmd == *-* ]] || exit 0

cwd=$(jq -r '.cwd // ""' <<<"$input")
[[ -d $cwd ]] && cd "$cwd"

# shellの単語に分け (z)、引用符を外す (Q)。`;` `&&` `|` などの区切りも1つの単語になる
words=("${(@Q)${(z)cmd}}")
files=() inline=() dynamic=0
i=1
while ((i <= ${#words})); do
    if [[ ${words[i]:t} == gh && (${words[i + 1]-} == pr && ${words[i + 2]-} == (create|edit|comment|review) ||
        ${words[i + 1]-} == issue && ${words[i + 2]-} == (create|edit|comment)) ]]; then
        ((i += 3))
        while ((i <= ${#words})); do
            w=${words[i]}
            case $w in
            ';' | '&&' | '||' | '|' | '&' | '(' | ')') break ;;
            -F | --body-file) files+=("${words[i + 1]-}") && ((i++)) ;;
            --body-file=*) files+=("${w#--body-file=}") ;;
            -b | --body) inline+=("${words[i + 1]-}") && ((i++)) ;;
            --body=*) inline+=("${w#--body=}") ;;
            esac
            ((i++))
        done
    fi
    ((i++))
done
((${#files} + ${#inline})) || exit 0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# 検査する本文を "表示名<TAB>ファイル" で集める
targets=()
for f in $files; do
    if [[ $f == - ]]; then
        dynamic=1
    elif [[ -f $f ]]; then
        targets+=("$f"$'\t'"$f")
    fi
done
n=0
for body in $inline; do
    if [[ $body == *'$('* || $body == *'`'* ]]; then
        dynamic=1
    else
        ((n++))
        print -r -- "$body" >"$tmp/inline$n.md"
        targets+=("--body ($n)"$'\t'"$tmp/inline$n.md")
    fi
done

if ((dynamic)); then
    jq -n '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: "PR・Issueの本文は、`$(...)` や標準入力ではなく、.mdファイルに書いて --body-file で渡すこと。"
        }
    }'
    exit 0
fi

findings=() bodies=()
for target in $targets; do
    label=${target%%$'\t'*} file=${target#*$'\t'}
    (($(wc -c <"$file") >= min_bytes)) || continue
    bodies+=("$(<"$file")")
    # 拡張子に関わらずMarkdownとして検査する
    cp "$file" "$tmp/body.md"
    out=$("$DOTPATH/script/tools/textlint.sh" report --format json "$tmp/body.md" 2>/dev/null)
    findings+=("${(@f)$(jq -r --arg label "$label" '.[0].messages[] | "\($label):\(.line):\(.column): \(.message | gsub("\n"; " ")) [\(.ruleId)]"' <<<"$out" 2>/dev/null)}")
done
findings=(${findings:#})
((${#findings})) || exit 0

# 同じ本文で再実行されたら、指摘を承知のうえで送るものとして通す
state="${TMPDIR:-/tmp}/gh-body-textlint"
mkdir -p "$state"
key=$(print -rl -- $bodies | cksum | tr ' ' '-')
[[ -e $state/$key ]] && exit 0
: >"$state/$key"

jq -n --arg findings "${(F)findings}" '{
    hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("本文にtextlintの指摘がある。指摘箇所を文意を保ったまま書き直してから再実行すること。指摘が誤りなら、同じ本文のまま再実行すれば通る。\n" + $findings)
    }
}'
exit 0
