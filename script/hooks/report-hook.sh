#!/usr/bin/env zsh
# agentが編集したファイルのうち、今回変わった行にある、自動では直さない指摘をagentへ返すPostToolUse hook。
#   - Markdown: textlintの指摘 (AIっぽい語、日本語の文章規則、空白など。ルールは config/textlint/textlintrc.report.json)
#   - シェルスクリプト: shellcheckの指摘と、Pythonなど他の言語のコードを `-c` / `-e` やheredocでべた書きした行。
#     zshのscriptはshellcheckの対象外 (shellcheckはzshに対応しておらず、bashとして読ませると誤った指摘が出る)
# 自動修正できるものは format-hook.sh が直す。
#
# 変わった行: gitで追跡中のファイルはHEADとの差分で追加・変更された行。追跡外・git管理外のファイルは全行。
# 既存のファイルにある古い書き方まで返すと、頼んでいない書き換えや直し続けるループが起きるため、変わった行に絞る。
#
# 指摘があるときはstderrに書いてexit 2で終える (Claude Code・Codexともにagentへのフィードバックになる)。
# textlint・shellcheckが無い・失敗した場合は、その検査だけ飛ばしてagentを止めない。

set -u

DOTPATH=${0:A:h:h:h}

command -v jq >/dev/null 2>&1 || exit 0

# 処理系の直後 (他のoptionの後でもよい) に -c / -e が来るか、heredocを渡す行。
# perlはsedの代わりの置換に使うことが多いので含めない
interp='(^|[^[:alnum:]_.-])(python3?|node|bun|deno|ruby)([[:space:]]+-[^[:space:]]*)*'
embedded="${interp}[[:space:]]+-[ce]([[:space:]]|\$)|${interp}[[:space:]]*<<"

report=()
for file in "${(@f)$("$DOTPATH/script/hooks/edited-files.sh")}"; do
    # "行番号<TAB>指摘" を1件1行で集め、変わった行のものだけ残す
    findings=()
    case $file in
    *.md)
        # .mjun/ はmjun系skillのagent向けのLocal文書 (spec、tasks、brief)。tasksはspecのAcceptance Criteriaを文言のまま写し、
        # Boundaryのような決まった書式の行もあるので、言い換えを促す指摘を返さない。人が読む文章は判断シートやPRで別に見る
        [[ $file == */.mjun/* || ${file:A} == */.mjun/* ]] && continue
        findings=("${(@f)$("$DOTPATH/script/tools/textlint.sh" report --format json "$file" 2>/dev/null |
            jq -r --arg file "$file" '.[0].messages[] | "\(.line)\t\($file):\(.line):\(.column): \(.message | gsub("\n"; " ")) [\(.ruleId)]"' 2>/dev/null)}")
        ;;
    *.sh | *.bash | *.zsh)
        read -r shebang <"$file"
        if [[ $file != *.zsh && $shebang != *zsh* ]] && command -v shellcheck >/dev/null 2>&1; then
            findings=("${(@f)$(shellcheck -f json1 "$file" 2>/dev/null |
                jq -r --arg file "$file" '.comments[] | "\(.line)\t\($file):\(.line):\(.column): \(.message) [SC\(.code)]"')}")
        fi
        for line in ${(f)"$(grep -nE "$embedded" "$file" | grep -vE '^[0-9]+:[[:space:]]*#' | cut -d: -f1)"}; do
            findings+=("$line"$'\t'"$file:$line: 他の言語のコードをべた書きしている。別ファイルのスクリプトにして呼び出すこと")
        done
        ;;
    *) continue ;;
    esac

    # 変わった行の範囲を {s: 開始行, n: 行数} の配列にする。null は全行
    ranges=null
    if git -C "${file:h}" ls-files --error-unmatch -- "$file" >/dev/null 2>&1 &&
        git -C "${file:h}" rev-parse -q --verify HEAD >/dev/null; then
        # hunk見出し "@@ -a,b +c,d @@" の新しい側 (c,d) を取り出す。dが無ければ1行、0なら削除だけ
        ranges=$(git -C "${file:h}" --no-pager diff --no-ext-diff --no-color -U0 HEAD -- "$file" |
            sed -nE 's/^@@ -[0-9,]+ \+([0-9]+)(,([0-9]+))? @@.*/\1 \3/p' |
            jq -Rn '[inputs | split(" ") | {s: (.[0] | tonumber), n: (if .[1] == "" then 1 else (.[1] | tonumber) end)}]')
    fi

    found=$(print -rl -- "${findings[@]}" | jq -Rr --argjson ranges "$ranges" '
        select(. != "") | split("\t") as [$l, $msg] | ($l | tonumber) as $l
        | select($ranges == null or ($ranges | any($l >= .s and $l < .s + .n)))
        | $msg')
    [[ -n $found ]] && report+=("$found")
done

((${#report[@]} > 0)) || exit 0

{
    print "今回編集した行に指摘があります。修正してください。日本語の文章は文意を保ったまま書き直してください。"
    print -l -- "${report[@]}"
} >&2
exit 2
