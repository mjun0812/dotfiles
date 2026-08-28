#!/usr/bin/env zsh
set -euo pipefail

# 全 workspace の番号 (prefix+shift+1..9 のジャンプ番号) を custom token `number`
# として報告する。展開した sidebar の Space 行が [ui.sidebar.spaces] の $number
# token でこれを表示する。番号は workspace の作成・削除・並び替えでずれるため、
# workspace 系 event で全件を貼り直す。

herdr_bin="${HERDR_BIN_PATH:-herdr}"

"$herdr_bin" workspace list |
    jq -r '.result.workspaces[] | "\(.workspace_id)\u001f\(.number)"' |
    while IFS=$'\037' read -r ws num; do
        "$herdr_bin" workspace report-metadata "$ws" --source workspace-number --token "number=$num" >/dev/null
    done
