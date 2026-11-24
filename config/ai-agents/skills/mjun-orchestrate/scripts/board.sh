#!/usr/bin/env zsh
# boardへtaskを足し、フィールドを書き換える。
# orchestratorが書き換えのたびにその場でscriptを書くと、出力が増え、status.shが読む書式も揺れる。
# usage:
#   board.sh add <run-dir> <slug> [<名前>=<値> ...] <依頼文   taskを末尾に足す。依頼文はstdinから読む
#   board.sh set <run-dir> <slug> <名前>=<値> ...            taskのフィールドを書き換える。無ければ足す
#   board.sh set <run-dir> - <名前>=<値> ...                 boardの先頭 (Workers、Finishなど) を書き換える
#   board.sh told <run-dir>                                  Told: noをすべてyesにし、Last tableを今にする
# 値が `now` なら今の時刻を書く。
# exit: 0 = 書き換えた、2 = 使い方の誤り、3 = setのtaskが無い・addのtaskが既にある
set -euo pipefail

me=${0:t}
usage() {
    print -u2 "usage: $me add|set <run-dir> <slug> [<名前>=<値> ...] | $me told <run-dir>"
    exit 2
}

(($# >= 2)) && [[ -f $2/board.md ]] || usage
cmd=$1 board=$2/board.md
shift 2
now=$(date '+%Y-%m-%d %H:%M')
# boardに並べる順。ここに無い名前は末尾に足す
order=(Status Told Agent Kind Branch Base 'Blocked by' Worker Started Finished Stops Result)
lines=("${(@f)$(<$board)}")

typeset -a names
typeset -A value
if [[ $cmd == (add|set) ]]; then
    (($# >= 1)) || usage
    slug=$1
    shift
    if [[ $cmd == add ]]; then
        names=(Status Told 'Blocked by' Stops)
        value=(Status pending Told yes 'Blocked by' none Stops 0)
    fi
    for pair; do
        [[ $pair == [A-Za-z]*=* ]] || usage
        name=${pair%%=*}
        names+=$name
        # 値は1行に収める (status.shは1行ずつ読む)
        value[$name]=${${pair#*=}//$'\n'/ }
        [[ $value[$name] == now ]] && value[$name]=$now
    done
fi

case $cmd in
add)
    ((${lines[(I)## $slug]} == 0)) || {
        print -u2 "$me: task $slug は既にある"
        exit 3
    }
    lines+=('' "## $slug" '')
    for name in $order ${names:|order}; do
        ((${names[(I)$name]})) && lines+="- $name: $value[$name]"
    done
    lines+=('' 'Request:' '')
    while IFS= read -r line; do
        lines+="${line:+    $line}"
    done
    ;;
set)
    (($#names)) || usage
    # taskの範囲は見出しの次の行から、次の見出しか依頼文の手前まで。`-` は最初の見出しの手前まで
    first=1
    if [[ $slug != - ]]; then
        first=${lines[(I)## $slug]}
        ((first)) || {
            print -u2 "$me: task $slug が無い"
            exit 3
        }
        ((first += 1))
    fi
    for name in ${(u)names}; do
        last=$first at=0 after=0
        for ((i = first; i <= $#lines; i++)); do
            [[ $lines[i] == ('## '*|Request:) ]] && break
            [[ $lines[i] =~ '^- ([A-Za-z ]+): ' ]] || continue
            last=$i found=$match[1]
            if [[ $found == $name ]]; then
                at=$i
                break
            fi
            # 並び順で後ろにあるフィールドを見つけたら、その手前に足す
            ((after == 0 && ${order[(I)$name]} && ${order[(I)$found]} > ${order[(I)$name]})) && after=$i
        done
        if ((at)); then
            lines[at]="- $name: $value[$name]"
        elif ((after)); then
            lines[after]=("- $name: $value[$name]" "$lines[after]")
        else
            lines[last]=("$lines[last]" "- $name: $value[$name]")
        fi
    done
    ;;
told)
    (($# == 0)) || usage
    lines=("${(@)lines/#%- Told: no/- Told: yes}")
    lines=("${(@)lines/#- Last table: */- Last table: $now}")
    ;;
*) usage ;;
esac

print -rl -- "${(@)lines}" >$board.tmp
mv $board.tmp $board
