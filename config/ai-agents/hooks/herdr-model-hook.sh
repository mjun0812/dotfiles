#!/usr/bin/env zsh
# herdrのagentsタブに出すCodexのモデル名 ($model token) を報告するhook (SessionStart / UserPromptSubmit)。
# どちらのhook入力にもmodelが必ず入るので、/modelでの切り替えは次のpromptで表示に反映される。
# SubAgentの発言でもUserPromptSubmitが呼ばれる (agent_idが入る) ため、SubAgentのモデルでは上書きしない。
# --agentを付けると、codexが終わった時点で表示が消える。

set -u

input=$(cat)
[[ ${HERDR_ENV:-} == 1 && -n ${HERDR_PANE_ID:-} ]] || exit 0
[[ -z $(jq -r '.agent_id // ""' <<<"$input") ]] || exit 0

"${HERDR_BIN_PATH:-herdr}" pane report-metadata "$HERDR_PANE_ID" \
    --source agent-model --agent codex --token "model=$(jq -r '.model' <<<"$input")" >/dev/null 2>&1
exit 0
