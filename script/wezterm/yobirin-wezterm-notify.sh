#!/usr/bin/env bash
set -euo pipefail

TITLE="${1:-Claude Code}"
MESSAGE="${2:-Notification}"
PANE_ID="${3:-}"
SESSION_ID="${4:-}"
PROFILE="${5:-}"

[[ $PANE_ID =~ ^[0-9]+$ ]] || exit 0
[[ $PROFILE =~ ^[a-z0-9]*$ ]] || PROFILE=""

# hook経由はPATHが薄いことがあるため、bundle symlinkとmise shimsへ明示的にfallbackする。
YOBIRIN_BIN="$(command -v yobirin || true)"
if [[ -z $YOBIRIN_BIN ]]; then
    for candidate in "$HOME/.local/bin/yobirin" "$HOME/.local/share/mise/shims/yobirin"; do
        if [[ -x $candidate ]]; then
            YOBIRIN_BIN="$candidate"
            break
        fi
    done
fi

[[ -n $YOBIRIN_BIN ]] || exit 0

# 指定プロファイルの派生バンドルが未インストールなら、デフォルトの名義へフォールバックする
# (yobirin list --json でインストール済みプロファイルを確認できる)。
if [[ -n $PROFILE ]] && command -v jq >/dev/null 2>&1; then
    if ! "$YOBIRIN_BIN" list --json 2>/dev/null |
        jq -e --arg p "$PROFILE" '.bundles[] | select(.profile == $p)' >/dev/null 2>&1; then
        PROFILE=""
    fi
fi

GROUP_ID="${SESSION_ID:-pane-${PANE_ID}}"

# yobirin は --timeout 省略時に無期限待機するため、hook からは必ず明示指定する。
RESULT="$(
    "$YOBIRIN_BIN" \
        ${PROFILE:+--profile "$PROFILE"} \
        --title "$TITLE" \
        --message "$MESSAGE" \
        --group "dotfiles-wezterm-${GROUP_ID}" \
        --timeout 300 \
        2>/dev/null || true
)"
RESULT_TYPE="$(printf '%s' "$RESULT" | jq -r '.result // empty' 2>/dev/null || true)"

if [[ $RESULT_TYPE == clicked || $RESULT_TYPE == action ]]; then
    "$HOME/.dotfiles/script/wezterm/activate-wezterm-pane.sh" "$PANE_ID" "$SESSION_ID"
fi
