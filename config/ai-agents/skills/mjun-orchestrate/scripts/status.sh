#!/usr/bin/env zsh
# board、Herdrが返すagentの状態、workerの報告ファイルを合わせて、taskの状態をMarkdownの表で出力する。
# boardのStatusはorchestratorが最後に確かめた値なので、runningのtaskはHerdrの今の状態で表示する。
# ユーザーへ伝え終えた完了task (Status: done かつ Told: yes) は件数だけを出す。
# usage: status.sh <run-dir>
# exit: 0 = 出力した、2 = 使い方の誤り、その他 = herdrかjqの失敗
set -euo pipefail
zmodload zsh/datetime

(($# == 1)) && [[ -f $1/board.md ]] || {
    print -u2 "usage: ${0:t} <run-dir>"
    exit 2
}
run_dir=$1

typeset -A pane_state
herdr agent list | jq -r '.result.agents[] | [.pane_id, .agent_status] | @tsv' |
    while IFS=$'\t' read -r pane state; do
        pane_state[$pane]=$state
    done

# 依頼文は字下げしてあるので、行頭の `## ` と `- ` はboardの見出しとフィールドだけに一致する。
# フィールド名の空白は `_` に置き換えて連想配列のキーにする
typeset -a slugs
typeset -A field
slug=
while IFS= read -r line; do
    if [[ $line == '## '* ]]; then
        slug=${line#\#\# }
        slugs+=$slug
    elif [[ -n $slug && $line =~ '^- ([A-Za-z ]+): (.*)$' ]]; then
        field[$slug,${match[1]// /_}]=$match[2]
    fi
done <$run_dir/board.md

typeset -a rows
told_done=0
for slug in $slugs; do
    board_status=${field[$slug,Status]:-}
    note=${field[$slug,Result]:-}
    report_status=
    [[ -f $run_dir/$slug.md ]] && report_status=$(sed -n 's/^Status: *//p' $run_dir/$slug.md | head -1)

    case $board_status in
    pending)
        label=未起動
        waiting=()
        for dep in ${(s:, :)field[$slug,Blocked_by]:-none}; do
            [[ $dep != none && ${field[$dep,Status]:-} != done ]] && waiting+=$dep
        done
        note=${waiting:+${(j:, :)waiting}待ち}
        ;;
    running)
        [[ ${field[$slug,Worker]:-} =~ 'pane ([^ ]+)' ]] && pane=$match[1] || pane=
        case ${pane_state[$pane]:-} in
        working) label=作業中 ;;
        blocked) label=入力待ち ;;
        idle | done) label=待機中 ;;
        unknown) label=不明 ;;
        *) label=pane無し ;;
        esac
        note=
        [[ $label != 作業中 && -n $report_status ]] && note="報告: $report_status"
        ;;
    needs-user) label=判断待ち ;;
    done)
        if [[ ${field[$slug,Told]:-} == yes ]]; then
            ((told_done += 1))
            continue
        fi
        label=完了
        [[ $report_status == DONE_WITH_CONCERNS ]] && label='完了 (懸念あり)'
        ;;
    *) label=${board_status:--} ;;
    esac

    elapsed=-
    if [[ -n ${field[$slug,Started]:-} ]]; then
        strftime -r -s from '%Y-%m-%d %H:%M' ${field[$slug,Started]}
        to=$EPOCHSECONDS
        [[ -n ${field[$slug,Finished]:-} ]] && strftime -r -s to '%Y-%m-%d %H:%M' ${field[$slug,Finished]}
        minutes=$(((to - from) / 60))
        ((minutes < 60)) && elapsed=${minutes}分 || elapsed=$((minutes / 60))時間$((minutes % 60))分
    fi

    ((${#note} > 80)) && note=${note[1,80]}…
    rows+="| $slug | ${field[$slug,Agent]:--} | $label | $elapsed | ${note//\|/\\|} |"
done

if ((${#rows})); then
    print '| task | agent | 状態 | 経過 | 待ち・結果 |'
    print '| --- | --- | --- | --- | --- |'
    print -rl -- $rows
fi
((told_done)) && print "\n伝え済みの完了: ${told_done}件"
exit 0
