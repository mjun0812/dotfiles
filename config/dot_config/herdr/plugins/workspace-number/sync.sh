#!/usr/bin/env zsh
set -euo pipefail

# 全workspaceの番号 (prefix+shift+1..9のジャンプ番号) をcustom token `number`
# として報告する。展開したsidebarのSpace行が[ui.sidebar.spaces]の$number
# tokenでこれを表示する。番号はworkspaceの作成・削除・並び替えでずれるため、
# workspace系eventで全件を貼り直す。最後のpaneのプロセス終了でworkspaceが
# 消えるときはworkspace.closedが発火しないため、pane.exitedでも貼り直す。

herdr_bin="${HERDR_BIN_PATH:-herdr}"

"$herdr_bin" workspace list |
    jq -r '.result.workspaces[] | "\(.workspace_id)\u001f\(.number)"' |
    while IFS=$'\037' read -r ws num; do
        "$herdr_bin" workspace report-metadata "$ws" --source workspace-number --token "number=$num" >/dev/null
    done
