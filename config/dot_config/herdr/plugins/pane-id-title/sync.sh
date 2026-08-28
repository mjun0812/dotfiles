#!/usr/bin/env zsh
set -euo pipefail

# 全 pane の label を「<pane_id> · <agent>」(agent なしの pane は <pane_id> のみ)
# に揃える。herdr の pane header は metadata title > label > agent 種別の
# 1 つしか表示しないため、agent 種別は label 側に合成する。
# ID 形式でない label (ユーザーの手動 rename) は上書きしない。

herdr_bin="${HERDR_BIN_PATH:-herdr}"
id_label_re='^w[0-9A-Za-z]+:p[0-9A-Za-z]+( · .*)?$'

"$herdr_bin" workspace list |
    jq -r '.result.workspaces[].workspace_id' |
    while read -r ws; do
        "$herdr_bin" pane list --workspace "$ws" |
            jq -r '.result.panes[] | [.pane_id, (.agent // ""), (.label // "")] | join("\u001f")' |
            while IFS=$'\037' read -r pane_id agent label; do
                desired="$pane_id"
                if [ -n "$agent" ]; then
                    desired="$pane_id · $agent"
                fi
                if [ "$label" = "$desired" ]; then
                    continue
                fi
                if [ -n "$label" ] && ! [[ $label =~ $id_label_re ]]; then
                    continue
                fi
                "$herdr_bin" pane rename "$pane_id" "$desired" >/dev/null
            done
    done
