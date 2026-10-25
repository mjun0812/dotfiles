#!/usr/bin/env zsh
# SubAgentのmodelとreasoning effortの指定を強制するCodexのPreToolUse hook (spawn_agent)。
# hookに届くtool名には名前空間が付く (例: collaborationspawn_agent) ため、matcherは末尾一致にする。
# modelはLuna・Sol・Astraのいずれか (例: gpt-6.1-sol) に限り、reasoning effortはmedium以上に限る。
# fork (fork_turnsが "none" 以外) は親の状態を引き継ぐため検査しない。

set -u

command -v jq >/dev/null 2>&1 || exit 0

# argumentsはJSON文字列で届く場合もあるので、objectに揃える
args=$(jq -c '.tool_input | if type == "string" then fromjson else . end' 2>/dev/null) || exit 0

fork_turns=$(jq -r '.fork_turns // "none"' <<<"$args")
[[ $fork_turns == none ]] || exit 0

model=$(jq -r '.model // ""' <<<"$args")
effort=$(jq -r '.reasoning_effort // ""' <<<"$args")

allowed_model='-(luna|sol|astra)$'
if [[ $model =~ $allowed_model && -n $effort && $effort != (none|minimal|low) ]]; then
    exit 0
fi

jq -n --arg model "${model:-未指定}" --arg effort "${effort:-未指定}" '{
    hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("spawn_agentにはmodel (Luna・Sol・Astraのいずれか) とreasoning_effort (medium以上) を指定すること。タスクの性質に応じてAGENTS.mdのSubAgentの基準で選ぶ。指定値: model=" + $model + ", reasoning_effort=" + $effort)
    }
}'
exit 0
