#!/bin/bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle AeroSpace (ON/OFF + HUD)
# @raycast.mode silent
# @raycast.packageName AeroSpace
# @raycast.icon 🧱

set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

AEROSPACE_BIN="$(command -v aerospace || true)"
if [[ -z ${AEROSPACE_BIN} ]]; then
    msg="❌ AeroSpace: aerospace が見つかりません"
    echo "$msg"
    exit 1
fi

# いまONならOFFにする（成功=いまOFFになった）
if "$AEROSPACE_BIN" enable off --fail-if-noop >/dev/null 2>&1; then
    msg="🛑 AeroSpace: OFF"
    echo "$msg"
    exit 0
fi

# いまOFFならONにする（成功=いまONになった）
if "$AEROSPACE_BIN" enable on --fail-if-noop >/dev/null 2>&1; then
    msg="✅ AeroSpace: ON"
    echo "$msg"
    exit 0
fi

msg="⚠️ AeroSpace: 切り替え失敗"
echo "$msg"
exit 1
