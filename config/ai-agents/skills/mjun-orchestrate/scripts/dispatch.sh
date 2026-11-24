#!/usr/bin/env zsh
# boardのtaskから依頼の本文を組み立ててworkerへ送り、受領を確かめてboardをrunningにする。
# 本文は templates/worker-prompt.md のcode blockを、boardとHerdrの値で埋めて作る。
# orchestratorが毎回全文を書き出すと、出力が増え、写し間違いも起きる。
# workerは `<orch名>-<slug>` の名前で起動済みであること。
# usage: dispatch.sh <run-dir> <slug>
# stdout: `received` か `not-received`
# exit: 0 = 受領した、1 = 送れなかった・受領を確かめられなかった (boardは変えない)、2 = 使い方の誤り、その他 = herdrかjqの失敗
set -euo pipefail

me=${0:t}
(($# == 2)) && [[ -f $1/board.md ]] || {
    print -u2 "usage: $me <run-dir> <slug>"
    exit 2
}
run_dir=${1:A} slug=$2
skill_dir=${0:A:h:h}

# boardの先頭と対象のtaskのフィールド、字下げを外した依頼文を読む
typeset -A field
typeset -a request_lines
section=- in_request=0
while IFS= read -r line; do
    if [[ $line == '## '* ]]; then
        section=${line#\#\# } in_request=0
    elif [[ $section == "$slug" && $line == Request: ]]; then
        in_request=1
    elif [[ $section == "$slug" ]] && ((in_request)); then
        request_lines+="${line#    }"
    elif [[ ($section == - || $section == "$slug") && $line =~ '^- ([A-Za-z ]+): (.*)$' ]]; then
        field[$match[1]]=$match[2]
    fi
done <$run_dir/board.md
while (($#request_lines)) && [[ -z $request_lines[1] ]]; do
    shift request_lines
done
while (($#request_lines)) && [[ -z $request_lines[-1] ]]; do
    shift -p request_lines
done
request=${(F)request_lines}

[[ -n ${field[Kind]:-} && -n $request ]] || {
    print -u2 "$me: boardにtask $slug のKindか依頼文が無い"
    exit 2
}
[[ ${field[Orchestrator]:-} =~ '^([^ ]+) .*pane ([^ ,)]+)' ]] || {
    print -u2 "$me: boardのOrchestratorからpane IDを読めない"
    exit 2
}
worker=$match[1]-$slug orch_pane=$match[2]
[[ ${field[Repository]:-} =~ 'default branch ([^)]+)' ]] && default_branch=$match[1] || default_branch=

info=$(herdr agent get $worker)
agent=$(jq -r '.result.agent.agent // ""' <<<$info)
[[ -n $agent ]] || {
    print -u2 -r -- "$me: worker $worker が起動していない: $info"
    exit 2
}
checkout=$(jq -r '.result.agent.cwd' <<<$info)
seq_before=$(jq -r '.result.agent.state_change_seq' <<<$info)

# 見出し `## $1` の下で最初に現れるcode blockの中身
block() {
    awk -v heading="## $1" '
        $0 == heading { found = 1; next }
        found && /^```/ { if (inside) exit; inside = 1; next }
        inside { print }
    ' $skill_dir/templates/worker-prompt.md
}

location=$(block "location_note: $field[Kind]")
base=${field[Base]:-}
[[ $field[Kind] == worktree && -n $base && $base != $default_branch && $base != ${default_branch#origin/} ]] &&
    location+=" $(block 'location_note: stacked')"
# Stop hookがorchestratorへ知らせるのはclaudeとcodexだけ (hooks/orch-worker-report.sh)
[[ $agent == (claude|codex) ]] && completion=$(block 'completion_note: hook') || completion=$(block 'completion_note: prompt')

# 文面の中のplaceholderも埋めるので、文面を先に入れる。依頼文は中身を書き換えないよう最後に入れる
body=$(block body)
fills=(
    location_note "$location" completion_note "$completion"
    memory_path $run_dir/memory.md slug $slug report_path $run_dir/$slug.md
    worker_name $worker orch_pane $orch_pane checkout_path "$checkout"
    branch "${field[Branch]:-}" base "$base" request "$request"
)
for ((i = 1; i < $#fills; i += 2)); do
    key="{{$fills[i]}}"
    body=${body//$key/$fills[i + 1]}
done

# agent_promptedは送信できたことしか示さないので、受領はstate_change_seqが進んだかで判定する
sent=$(herdr agent prompt $worker "$body") && [[ $(jq -r '.error // ""' <<<$sent) == '' ]] || {
    print -u2 -r -- $sent
    print not-received
    exit 1
}
herdr agent wait $worker --until working --timeout 15000 >/dev/null 2>&1 || true
info=$(herdr agent get $worker)
if (($(jq -r '.result.agent.state_change_seq' <<<$info) <= seq_before)); then
    print not-received
    exit 1
fi
zsh $skill_dir/scripts/board.sh set $run_dir $slug Status=running Started=now \
    "Worker=$worker / pane $(jq -r '.result.agent.pane_id' <<<$info) / workspace $(jq -r '.result.agent.workspace_id' <<<$info)"
print received
