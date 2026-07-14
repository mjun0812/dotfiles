#!/usr/bin/env bash
set -euo pipefail

PANE_ID="${1:-}"
SESSION_ID="${2:-}"

[[ $PANE_ID =~ ^[0-9]+$ ]] || exit 0

if [[ $SESSION_ID =~ ^[[:alnum:]_-]+$ ]]; then
    open -g "hammerspoon://claude-wezterm-focus?session=${SESSION_ID}&pane=${PANE_ID}" \
        >/dev/null 2>&1 || true
    exit 0
fi

WEZTERM_BIN="$(command -v wezterm || true)"
if [[ -z $WEZTERM_BIN ]]; then
    for candidate in /opt/homebrew/bin/wezterm /usr/local/bin/wezterm; do
        if [[ -x $candidate ]]; then
            WEZTERM_BIN="$candidate"
            break
        fi
    done
fi

[[ -n $WEZTERM_BIN ]] || exit 0
"$WEZTERM_BIN" cli activate-pane --pane-id "$PANE_ID" >/dev/null 2>&1 || true
