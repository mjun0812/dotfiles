#!/usr/bin/env bash
set -euo pipefail

INPUT="$(cat || true)"
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)"

[[ $(uname -s) == Darwin* ]] || exit 0
command -v open >/dev/null 2>&1 || exit 0
[[ $SESSION_ID =~ ^[[:alnum:]_-]+$ ]] || exit 0

PANE_ID="${WEZTERM_PANE:-}"
if [[ -z $PANE_ID && ${TERM_PROGRAM:-} == "WezTerm" ]] && command -v wezterm >/dev/null 2>&1; then
    CURRENT_TTY="$(ps -o tty= -p "$PPID" 2>/dev/null | tr -d ' ')"
    if [[ -n $CURRENT_TTY && $CURRENT_TTY != "??" ]]; then
        [[ $CURRENT_TTY == /dev/* ]] || CURRENT_TTY="/dev/$CURRENT_TTY"
        PANE_ID="$(wezterm cli list --format json 2>/dev/null | jq -r --arg tty "$CURRENT_TTY" 'first(.[] | select(.tty_name == $tty) | .pane_id) // empty' 2>/dev/null || true)"
    fi
fi

[[ $PANE_ID =~ ^[0-9]+$ ]] || exit 0

nohup open -g "hammerspoon://claude-wezterm-capture?session=${SESSION_ID}&pane=${PANE_ID}" \
    >/dev/null 2>&1 </dev/null &
