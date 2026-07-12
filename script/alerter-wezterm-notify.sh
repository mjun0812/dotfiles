#!/usr/bin/env bash
set -euo pipefail

TITLE="${1:-Claude Code}"
MESSAGE="${2:-Notification}"
PANE_ID="${3:-}"

[[ $PANE_ID =~ ^[0-9]+$ ]] || exit 0

ALERTER_BIN="$(command -v alerter || true)"
if [[ -z $ALERTER_BIN ]]; then
    for candidate in /opt/homebrew/bin/alerter /usr/local/bin/alerter; do
        if [[ -x $candidate ]]; then
            ALERTER_BIN="$candidate"
            break
        fi
    done
fi

[[ -n $ALERTER_BIN ]] || exit 0

RESULT="$(
    "$ALERTER_BIN" \
        --title "$TITLE" \
        --message "$MESSAGE" \
        --group "dotfiles-wezterm-$PANE_ID" \
        --json 2>/dev/null || true
)"
ACTIVATION_TYPE="$(printf '%s' "$RESULT" | jq -r '.activationType // empty' 2>/dev/null || true)"
if [[ $ACTIVATION_TYPE == contentsClicked || $ACTIVATION_TYPE == actionClicked ]]; then
    "$HOME/.dotfiles/script/activate-wezterm-pane.sh" "$PANE_ID"
fi
