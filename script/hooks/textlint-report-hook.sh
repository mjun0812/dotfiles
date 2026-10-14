#!/usr/bin/env zsh
# agentが編集したMarkdownのうち、今回変わった行にある自動修正できない指摘 (AIっぽい語、日本語の文章規則など) をagentへ返すPostToolUse hook。
# 自動修正できるルールは format-hook.sh が直す。ルールは config/textlint/textlintrc.report.json。
#
# 変わった行: gitで追跡中のファイルはHEADとの差分で追加・変更された行。追跡外・git管理外のファイルは全行。
# 既存の文書にある古い表現まで返すと、頼んでいない書き換えや直し続けるループが起きるため、変わった行に絞る。
#
# 指摘があるときはstderrに書いてexit 2で終える (Claude Code・Codexともにagentへのフィードバックになる)。
# textlintが無い・失敗した場合はagentを止めないようexit 0で終える。

set -u

DOTPATH=${0:A:h:h:h}

command -v jq >/dev/null 2>&1 || exit 0

report=()
for file in "${(@f)$("$DOTPATH/script/hooks/edited-files.sh")}"; do
    [[ $file == *.md ]] || continue

    # 変わった行の範囲を {s: 開始行, n: 行数} の配列にする。null は全行
    ranges=null
    if git -C "${file:h}" ls-files --error-unmatch -- "$file" >/dev/null 2>&1 &&
        git -C "${file:h}" rev-parse -q --verify HEAD >/dev/null; then
        # hunk見出し "@@ -a,b +c,d @@" の新しい側 (c,d) を取り出す。dが無ければ1行、0なら削除だけ
        ranges=$(git -C "${file:h}" --no-pager diff --no-ext-diff --no-color -U0 HEAD -- "$file" |
            sed -nE 's/^@@ -[0-9,]+ \+([0-9]+)(,([0-9]+))? @@.*/\1 \3/p' |
            jq -Rn '[inputs | split(" ") | {s: (.[0] | tonumber), n: (if .[1] == "" then 1 else (.[1] | tonumber) end)}]')
    fi

    result=$("$DOTPATH/script/tools/textlint.sh" report --format json "$file" 2>/dev/null)
    [[ -n $result ]] || continue

    found=$(jq -r --arg file "$file" --argjson ranges "$ranges" '
        .[0].messages[]
        | select(.line as $l | $ranges == null or ($ranges | any($l >= .s and $l < .s + .n)))
        | "\($file):\(.line):\(.column): \(.message) [\(.ruleId)]"' <<<"$result" 2>/dev/null)
    [[ -n $found ]] && report+=("$found")
done

((${#report[@]} > 0)) || exit 0

{
    print "今回編集した行に、日本語の文章規則の指摘があります。文意を保ったまま書き直してください。"
    print -l -- "${report[@]}"
} >&2
exit 2
