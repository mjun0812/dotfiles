#!/usr/bin/env zsh
# 他人が作成したGitHub Issueの本文を `gh issue edit --body / --body-file` で書き換える呼び出しを拒否する
# Claude Code・CodexのPreToolUse hook (Bash)。本文は作成者の言葉なので、追記や提案はコメントで行わせる。
# 題名・label・assigneeなどの変更と、bot (Renovateのdashboardなど) が作成したIssueは通す。
# 作成者を確かめられない (gh・jqが無い、API呼び出しに失敗した) ときは止めない。

set -u

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
[[ $cmd == *issue* && $cmd == *edit* && $cmd == *-* ]] || exit 0

# shellの単語に分け (z)、引用符を外す (Q)。`;` `&&` `|` などの区切りも1つの単語になる
words=("${(@Q)${(z)cmd}}")
targets=()
i=1
while ((i <= ${#words})); do
    if [[ ${words[i]:t} == gh && ${words[i + 1]-} == issue && ${words[i + 2]-} == edit ]]; then
        ((i += 3))
        body=0 repo="" issues=()
        while ((i <= ${#words})); do
            w=${words[i]}
            case $w in
            ';' | '&&' | '||' | '|' | '&' | '(' | ')') break ;;
            -b | --body | -F | --body-file) body=1 && ((i++)) ;;
            --body=* | --body-file=*) body=1 ;;
            -R | --repo) repo=${words[i + 1]-} && ((i++)) ;;
            --repo=*) repo=${w#--repo=} ;;
            --remove-milestone) ;;
            # 残りのflagは値を1つ取る (--add-label、-t など)
            -?*) [[ $w == --*=* ]] || ((i++)) ;;
            *) issues+=("$w") ;;
            esac
            ((i++))
        done
        ((body)) && for issue in $issues; do targets+=("$issue"$'\t'"$repo"); done
    fi
    ((i++))
done
((${#targets})) || exit 0

gh=$(command -v gh 2>/dev/null || mise which gh 2>/dev/null) || exit 0
cwd=$(jq -r '.cwd // ""' <<<"$input")
[[ -d $cwd ]] && cd "$cwd"
me=$("$gh" api user --jq .login 2>/dev/null) || exit 0

for target in $targets; do
    issue=${target%%$'\t'*} repo=${target#*$'\t'}
    args=(issue view "$issue" --json author --jq '.author | "\(.login)\t\(.is_bot)"')
    [[ -n $repo ]] && args+=(-R "$repo")
    author=$("$gh" $args 2>/dev/null) || continue
    login=${author%%$'\t'*} is_bot=${author#*$'\t'}
    [[ -n $login && $login != "$me" && $is_bot != true ]] || continue

    jq -n --arg reason "他人 (@$login) が作成したIssue $issue の本文は書き換えないこと。追記や提案は gh issue comment でコメントとして投稿すること。本文の変更がどうしても必要なら、ユーザーに手作業を依頼すること。" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $reason
        }
    }'
    exit 0
done
exit 0
