#!/usr/bin/env zsh
# apply_patchが触るファイルに合うagent向けのrule (config/ai-agents/rules/*.md) を、additionalContextでagentへ渡すCodexのhook。
#   PreToolUse (apply_patch): ruleを渡す。編集は止めないので、ruleが届くのはその編集の後になる
#   PostCompact: 渡した記録を消す。compactionで渡したruleがcontextから消えるため
# Claude Codeはruleのfrontmatterのpathsを見て自分で読み込む。Codexには同じ機能が無いので、このhookが同じファイルを読んで渡す。
# 同じsessionで同じruleは1回だけ渡す。ruleの本文が変わったら渡し直す。
# globは、ファイルのあるgit repositoryのtop level (git管理外ならsessionのcwd) からの相対パスと照合する。

set -u
setopt extended_glob

DOTPATH=${0:A:h:h:h}

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
session=$(jq -r '.session_id // "unknown"' <<<"$input")
cwd=$(jq -r '.cwd // ""' <<<"$input")
state_dir="${TMPDIR:-/tmp}/codex-rules-hook/$session"

if [[ $(jq -r '.hook_event_name // ""' <<<"$input") == PostCompact ]]; then
    rm -rf "$state_dir"
    exit 0
fi

# patchの見出しから、触るファイルをrootからの相対パスで取り出す ("Move to" は移動後のパス)。
# 追加するファイルはまだ無いので、存在する親ディレクトリからrootを探す
paths=()
for file in ${(f)"$(jq -r '.tool_input.command // ""' <<<"$input" | sed -nE 's/^\*\*\* (Add File|Update File|Move to): //p')"}; do
    [[ $file == /* ]] || file="$cwd/$file"
    dir=${file:h}
    while [[ ! -d $dir ]]; do dir=${dir:h}; done
    root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || root=$cwd
    paths+=("${${file:A}#${root:A}/}")
done
((${#paths})) || exit 0

context=()
for rule in "$DOTPATH"/config/ai-agents/rules/*.md(N); do
    globs=(${(f)"$("$DOTPATH/script/tools/rule-paths.sh" "$rule" 2>/dev/null)"})
    ((${#globs})) || continue

    # Claude Codeのglobをzshのパターンにする。`**` は0個以上のディレクトリ、`*` と `?` は `/` をまたがない
    matched=0
    for glob in $globs; do
        segments=(${(s:/:)glob})
        pattern=""
        for ((j = 1; j <= ${#segments}; j++)); do
            if [[ ${segments[j]} == '**' ]]; then
                ((j == ${#segments})) && pattern+='*' || pattern+='(*/|)'
                continue
            fi
            segment=${segments[j]//\*/'[^/]#'}
            pattern+=${segment//\?/'[^/]'}
            ((j < ${#segments})) && pattern+='/'
        done
        for path_ in $paths; do
            [[ $path_ == ${~pattern} ]] && matched=1 && break 2
        done
    done
    ((matched)) || continue

    # frontmatter (`---`、`paths:`、globの行、`---`) の後が本文
    body=$(tail -n +$((${#globs} + 4)) "$rule" | sed '/./,$!d')
    mark="$state_dir/${rule:t}"
    [[ -f $mark && $(<"$mark") == "$body" ]] && continue
    mkdir -p "$state_dir"
    print -r -- "$body" >|"$mark"
    context+=("$body")
done
((${#context})) || exit 0

jq -n --arg body "${(pj:\n\n:)context}" '{
    hookSpecificOutput: {
        hookEventName: "PreToolUse",
        additionalContext: ("今編集したファイルに適用されるruleです。以降の編集では、このruleに従うこと。必要なら今の編集も直すこと。\n\n" + $body)
    }
}'
exit 0
