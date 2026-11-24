#!/usr/bin/env zsh
# mjun-orchestrateのworkerのsessionを見分け、workerが止まったときに報告ファイルの状態と要点を
# orchestratorのpaneへ1行で送る。workerに送らせると、turnの途中で届き、送り忘れも起きる。
# notify-claude-hook.shとnotify-codex-hook.shが、hookの入力JSONをstdinに渡して呼ぶ。
#
# workerかどうかは、orchestratorが送った依頼の本文で見分ける。本文には報告ファイルのパスを指定する文があり
# (skills/mjun-orchestrate/templates/worker-prompt.md)、UserPromptSubmitでそれを見つけたsessionを記録する。
# 環境変数は使えない。Codexは共有のdaemonでhookを動かすので、paneに付けた変数がhookに届かない。
#
# 宛先のpaneは起動時の値ではなくboardから読む。orchestratorのpaneは、ユーザーが移動するとIDが変わる。
# 送るのは、報告ファイルが前回の送信から変わったときだけにする。
# Stopはturnごとに発火するので、追加の指示に答えただけのturnでも呼ばれる。
# 送れなかったとき (orchestratorが質問の回答待ちで受け取れないなど) は記録せず、次のStopでもう一度送る。
#
# usage: orch-worker-report.sh <event> <hookの入力JSON
# exit: 0 = workerのsession (呼び出し元はユーザーへの通知を出さない)、1 = workerではない

input=$(cat)
session=$(jq -r '.session_id // ""' <<<$input 2>/dev/null)
[[ $session =~ '^[[:alnum:]_-]+$' ]] || exit 1
mark=${TMPDIR:-/tmp}/mjun-orch-worker-$session

if [[ $1 == turn_start ]]; then
    prompt=$(jq -r '.prompt // ""' <<<$input 2>/dev/null)
    [[ $prompt =~ 'Write your report to (/[^ ]+/\.mjun/orchestrate/[^ ]+\.md) when you finish' ]] &&
        print -r -- $match[1] >$mark
fi
[[ -f $mark ]] || exit 1
[[ $1 == stop ]] || exit 0

report=$(<$mark)
[[ -f $report && -f ${report:h}/board.md ]] || exit 0
sum=$(cksum <$report)
[[ -f $report.sent && $(<$report.sent) == $sum ]] && exit 0

report_status=$(sed -n 's/^Status: *//p' $report | head -1)
[[ $report_status == (DONE|DONE_WITH_CONCERNS|NEEDS_CONTEXT|BLOCKED) ]] || exit 0

[[ $(grep -m1 '^- Orchestrator: ' ${report:h}/board.md) =~ '^- Orchestrator: ([^ ]+) .*pane ([^ ,)]+)' ]] || exit 0
worker=$match[1]-${report:t:r} orch_pane=$match[2]

# `## Result` の下で最初の空でない行を要点にする
summary=$(awk '/^## Result/ { found = 1; next } found && /^## / { exit } found && NF { print; exit }' $report)
pr=$(sed -n 's/^PR: *//p' $report | head -1)
message="$report_status $worker: ${summary[1,200]}${pr:+ $pr}"

# Codexのhookは絞られたPATHで動き、miseが入れたherdrを見つけられないことがある
herdr=${HERDR_BIN_PATH:-$(command -v herdr 2>/dev/null || mise which herdr 2>/dev/null)}
sent=$($herdr agent prompt $orch_pane "$message" 2>/dev/null) && [[ $sent != *'"error"'* ]] &&
    print -r -- $sum >$report.sent
exit 0
