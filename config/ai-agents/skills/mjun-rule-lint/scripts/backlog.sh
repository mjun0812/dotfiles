#!/usr/bin/env zsh
# lintの候補 (<repo>/.mjun/lint/backlog.tsv) を貯め、同じ種類が何件たまったかを数える。
# レビューで出た書き方の指摘は、1回ではlintにしない (例外の多いlintが増える)。
# 2回出たことを数えるには記録が要るので、mjun-implementが指摘のたびにここへ足す。
# usage:
#   backlog.sh add <repo-root> <key> <出典> <file:line> <指摘の1行>   候補を1件足し、そのkeyの件数を出す
#   backlog.sh list <repo-root> [<最小件数>]                          閉じていないkeyを、件数と最新の指摘つきで出す
#   backlog.sh close <repo-root> <key> <理由>                         lintにした、または見送ったkeyを閉じる
# keyは種類を表すkebab-caseの名前。足す前にlistで既存のkeyを見て、同じ種類なら同じkeyを使う。
# 同じkeyで同じ場所の指摘は足さない (差し戻しの後に同じ箇所へ出た指摘を、2回と数えないため)。
# exit: 0 = 成功、2 = 使い方の誤り
set -euo pipefail

me=${0:t}
usage() {
    print -u2 "usage: $me add <repo-root> <key> <出典> <file:line> <指摘> | $me list <repo-root> [<最小件数>] | $me close <repo-root> <key> <理由>"
    exit 2
}

(($# >= 2)) && [[ -d $2 ]] || usage
cmd=$1 file=$2/.mjun/lint/backlog.tsv
shift 2
# 1行は「日付 key 出典 場所 指摘」のタブ区切り。閉じたkeyは、出典の欄をclosedにした行で表す
tab=$'\t' newline=$'\n'
fields=("${(@)@//[$tab$newline]/ }")
lines=()
[[ -f $file ]] && lines=("${(@f)$(<$file)}")

case $cmd in
add)
    (($# == 4)) && [[ $1 =~ '^[a-z0-9][a-z0-9-]*$' ]] || usage
    count=0 known=0
    for line in $lines; do
        row=("${(@ps:\t:)line}")
        [[ $row[2] == $1 && $row[3] != closed ]] || continue
        ((count += 1))
        [[ $row[4] == $fields[3] ]] && known=1
    done
    if ((known == 0)); then
        mkdir -p ${file:h}
        print -r -- "$(date +%Y-%m-%d)"$'\t'"${(pj:\t:)fields}" >>$file
        ((count += 1))
    fi
    print -r -- "$1: ${count}件"
    ;;
list)
    (($# <= 1)) || usage
    typeset -A count latest closed
    keys=()
    for line in $lines; do
        row=("${(@ps:\t:)line}")
        if [[ $row[3] == closed ]]; then
            closed[$row[2]]=1
            continue
        fi
        ((${+count[$row[2]]})) || keys+=$row[2]
        count[$row[2]]=$((${count[$row[2]]:-0} + 1))
        latest[$row[2]]="$row[5] ($row[3]、$row[4])"
    done
    for key in $keys; do
        ((${+closed[$key]} == 0 && count[$key] >= ${1:-1})) && print -r -- "$key: ${count[$key]}件。最新: $latest[$key]"
    done
    ;;
close)
    (($# == 2)) || usage
    mkdir -p ${file:h}
    print -r -- "$(date +%Y-%m-%d)"$'\t'"$fields[1]"$'\t'"closed"$'\t'"-"$'\t'"$fields[2]" >>$file
    ;;
*) usage ;;
esac
exit 0
