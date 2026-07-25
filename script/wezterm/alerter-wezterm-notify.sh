#!/usr/bin/env bash
set -euo pipefail

TITLE="${1:-Claude Code}"
MESSAGE="${2:-Notification}"
PANE_ID="${3:-}"
SESSION_ID="${4:-}"
APP_ICON="${5:-}"

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

GROUP_ID="${SESSION_ID:-pane-${PANE_ID}}"

# --app-icon は private API 依存のため、指定が無い/ファイルが無い場合は付けずに既定アイコンで通知する。
# macOS 標準の bash 3.2 では set -u 下で空配列を "${arr[@]}" 展開できないため ${arr[@]+...} を使う。
ICON_ARGS=()
if [[ -n $APP_ICON && -f $APP_ICON ]]; then
    ICON_ARGS=(--app-icon "$APP_ICON")
fi

RESULT="$(
    "$ALERTER_BIN" \
        --title "$TITLE" \
        --message "$MESSAGE" \
        --group "dotfiles-wezterm-${GROUP_ID}" \
        ${ICON_ARGS[@]+"${ICON_ARGS[@]}"} \
        --json 2>/dev/null || true
)"
ACTIVATION_TYPE="$(printf '%s' "$RESULT" | jq -r '.activationType // empty' 2>/dev/null || true)"

if [[ $ACTIVATION_TYPE == contentsClicked || $ACTIVATION_TYPE == actionClicked ]]; then
    "$HOME/.dotfiles/script/wezterm/activate-wezterm-pane.sh" "$PANE_ID" "$SESSION_ID"
fi
