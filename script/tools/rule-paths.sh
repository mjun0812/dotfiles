#!/usr/bin/env zsh
# agent向けのrule (config/ai-agents/rules/*.md) のfrontmatterを検査し、pathsのglobを1行ずつ出力する。
# 使い方: rule-paths.sh <rule.md>...
# 書式が外れたファイルがあれば、stderrに理由を書いてexit 1で終える (prekの検査として使う)。
# Claude Codeはfrontmatterを自分で読み、Codexは codex-rules-hook.sh がこのscriptで読む。同じ書式を両方が同じ意味で読めるよう、書式を次に限る。
#   1行目 `---`、2行目 `paths:`、続けて `  - "<glob>"` を1行以上、最後に `---`
#   globに使えるのは英数字と `_` `.` `/` `-`、`*`、`?`、ディレクトリ全体を表す `**` だけ。
#   `{a,b}` などそれ以外のglobは、hookでClaude Codeと同じ意味に照合できないので使わない

set -u

result=0
for file in "$@"; do
    lines=("${(@f)$(<"$file")}")
    globs=()
    error=""
    i=3
    while [[ ${lines[i]-} == '  - "'*'"' ]]; do
        glob=${${lines[i]#'  - "'}%'"'}
        if [[ ! $glob =~ '^[A-Za-z0-9_./*?-]+$' ]]; then
            error="${i}行目: globに使えない文字がある: $glob"
            break
        fi
        for segment in ${(s:/:)glob}; do
            [[ $segment == *'**'* && $segment != '**' ]] && error="${i}行目: ** はディレクトリ全体 (/**/) にだけ使う: $glob"
        done
        [[ -n $error ]] && break
        globs+=("$glob")
        ((i++))
    done

    if [[ -z $error ]]; then
        if [[ ${lines[1]-} != --- ]]; then
            error="1行目が --- ではない"
        elif [[ ${lines[2]-} != paths: ]]; then
            error="2行目が paths: ではない"
        elif ((${#globs} == 0)); then
            error='3行目: pathsに  - "<glob>" の行が無い'
        elif [[ ${lines[i]-} != --- ]]; then
            error="${i}行目: pathsの後が --- ではない: ${lines[i]-}"
        fi
    fi

    if [[ -n $error ]]; then
        print -u2 -- "$file: $error"
        result=1
        continue
    fi
    print -rl -- "${globs[@]}"
done
exit $result
