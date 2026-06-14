#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Float Window
# @raycast.mode silent
# @raycast.packageName AeroSpace

set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

if ! command -v aerospace >/dev/null 2>&1; then
    echo "aerospace が見つかりません（PATH を確認）"
    exit 1
fi

# フォーカスウィンドウの親レイアウトを取得（floating / v_tiles / h_tiles / ...）  [oai_citation:6‡nikitabobko.github.io](https://nikitabobko.github.io/AeroSpace/commands)
layout="$(
    aerospace list-windows --focused --format "%{window-parent-container-layout}" 2>/dev/null |
        head -n1 |
        tr -d '[:space:]'
)" || true

if [[ -z ${layout:-} ]]; then
    echo "フォーカス中のウィンドウがありません"
    exit 1
fi

# floating でなければ floating にする（ここは「トグル」ではなく「寄せる前に floating 化」）
if [[ $layout != "floating" ]]; then
    aerospace layout floating
fi

open -g "hammerspoon://center"
