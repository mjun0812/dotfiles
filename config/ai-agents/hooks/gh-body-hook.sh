#!/usr/bin/env zsh
# `gh pr|issue create|edit|comment`と`gh pr review`で送る本文を検査するClaude Code・CodexのPreToolUse hook (Bash)。
#   1. 他人が作成したIssueの本文を`gh issue edit --body / --body-file`で書き換える呼び出しを拒否する。
#      本文は作成者の言葉なので、追記や提案はコメントで行わせる。題名・label・assigneeなどの変更と、
#      bot (Renovateのdashboardなど) が作成したIssueは通す。作成者を確かめられないときは止めない。
#   2. 本文にtextlintをかけ、指摘があれば一度だけ止めて書き直させる。同じ本文で再実行したら通すので、誤検知でも先へ進める。
#      本文の展開結果はhookから見えないため、`$(...)`や`--body-file -`で渡す本文は、ファイルに書いて--body-fileで渡させる。
#      commitメッセージやひと言のコメントのような短い本文は検査しない。textlintが失敗したときは止めない。

set -u

command -v jq >/dev/null 2>&1 || exit 0

DOTPATH=${0:A:h:h:h:h}
# この長さ未満の本文はtextlintにかけない (日本語でおよそ100文字)
min_bytes=300

input=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
[[ $cmd == *gh* && ($cmd == *pr* || $cmd == *issue*) && $cmd == *-* ]] || exit 0

cwd=$(jq -r '.cwd // ""' <<<"$input")
[[ -d $cwd ]] && cd "$cwd"

deny() {
    jq -n --arg reason "$1" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $reason
        }
    }'
    exit 0
}

# shellの単語に分け (z)、引用符を外す (Q)。`;` `&&` `|`などの区切りも1つの単語になる
words=("${(@Q)${(z)cmd}}")
files=() inline=() edited_issues=()
i=1
while ((i <= ${#words})); do
    if [[ ${words[i]:t} == gh && (${words[i + 1]-} == pr && ${words[i + 2]-} == (create|edit|comment|review) ||
        ${words[i + 1]-} == issue && ${words[i + 2]-} == (create|edit|comment)) ]]; then
        [[ ${words[i + 1]} == issue && ${words[i + 2]} == edit ]] && issue_edit=1 || issue_edit=0
        ((i += 3))
        body=0 repo="" issues=()
        while ((i <= ${#words})); do
            w=${words[i]}
            case $w in
            ';' | '&&' | '||' | '|' | '&' | '(' | ')') break ;;
            -F | --body-file) body=1 && files+=("${words[i + 1]-}") && ((i++)) ;;
            --body-file=*) body=1 && files+=("${w#--body-file=}") ;;
            -b | --body) body=1 && inline+=("${words[i + 1]-}") && ((i++)) ;;
            --body=*) body=1 && inline+=("${w#--body=}") ;;
            -R | --repo) repo=${words[i + 1]-} && ((i++)) ;;
            --repo=*) repo=${w#--repo=} ;;
            --remove-milestone) ;;
            # gh issue editの残りのflagは値を1つ取る (--add-label、-tなど)。
            # 他のsubcommandには値を取らないflag (--draftなど) があるので、次の単語を飛ばさない
            -?*) ((issue_edit)) && [[ $w != --*=* ]] && ((i++)) ;;
            *) ((issue_edit)) && issues+=("$w") ;;
            esac
            ((i++))
        done
        ((issue_edit && body)) && for issue in $issues; do edited_issues+=("$issue"$'\t'"$repo"); done
    fi
    ((i++))
done
((${#files} + ${#inline})) || exit 0

if ((${#edited_issues})); then
    gh=$(command -v gh 2>/dev/null || mise which gh 2>/dev/null)
    me=$([[ -n $gh ]] && "$gh" api user --jq .login 2>/dev/null)
    [[ -n $me ]] && for target in $edited_issues; do
        issue=${target%%$'\t'*} repo=${target#*$'\t'}
        args=(issue view "$issue" --json author --jq '.author | "\(.login)\t\(.is_bot)"')
        [[ -n $repo ]] && args+=(-R "$repo")
        author=$("$gh" $args 2>/dev/null) || continue
        login=${author%%$'\t'*} is_bot=${author#*$'\t'}
        [[ -n $login && $login != "$me" && $is_bot != true ]] || continue
        deny "他人 (@$login) が作成したIssue $issue の本文は書き換えないこと。追記や提案は gh issue comment でコメントとして投稿すること。本文の変更がどうしても必要なら、ユーザーに手作業を依頼すること。"
    done
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# 検査する本文を"表示名<TAB>ファイル"で集める
targets=() dynamic=0
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
((dynamic)) && deny 'PR・Issueの本文は、`$(...)` や標準入力ではなく、.mdファイルに書いて --body-file で渡すこと。'

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

deny "本文にtextlintの指摘がある。指摘箇所を文意を保ったまま書き直してから再実行すること。指摘が誤りなら、同じ本文のまま再実行すれば通る。"$'\n'"${(F)findings}"
