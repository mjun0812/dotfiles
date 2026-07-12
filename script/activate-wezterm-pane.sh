#!/usr/bin/env bash
set -euo pipefail

PANE_ID="${1:-}"
[[ $PANE_ID =~ ^[0-9]+$ ]] || exit 0

open -a WezTerm >/dev/null 2>&1 || true

WEZTERM_BIN=""
for candidate in /opt/homebrew/bin/wezterm /usr/local/bin/wezterm; do
    if [[ -x $candidate ]]; then
        WEZTERM_BIN="$candidate"
        break
    fi
done
if [[ -z $WEZTERM_BIN ]]; then
    WEZTERM_BIN="$(command -v wezterm || true)"
fi

[[ -n $WEZTERM_BIN ]] || exit 0
"$WEZTERM_BIN" cli activate-pane --pane-id "$PANE_ID" >/dev/null 2>&1 || true
