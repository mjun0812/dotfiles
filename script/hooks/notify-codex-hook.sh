#!/usr/bin/env bash
set -euo pipefail

# notify-codex-hook.sh
#
# Codex の hook (UserPromptSubmit / Stop / PermissionRequest) から
# stdin で渡される JSON を読み、リポジトリ名・セッションID短縮・実メッセージを含む
# 通知を notify.sh 経由で送出する。
#
# Codex には Claude Code の terminalSequence に相当する hook 出力プロトコルが無いため、
# notify.sh の自動判定 (ローカルはネイティブ通知、SSH は /dev/tty への OSC) に委ねる。
#
# hook 定義を変更すると Codex の信頼ハッシュが無効になり再承認が必要になるため、
# 通知の条件や文言はすべてこのスクリプト側に置き、hooks.json にはパスだけを書く。
#
# Usage:
#   notify-codex-hook.sh <event>
#     event: turn_start | stop | permission

# 応答がこの秒数未満で終わったターンでは stop の通知を出さない。
MIN_ELAPSED_SEC=60

EVENT="${1:-stop}"
INPUT="$(cat || true)"

jq_get() {
    printf '%s' "$INPUT" | jq -r "($1) // \"\"" 2>/dev/null || printf ''
}

# 通知本文に載せるため、改行の除去・連続空白の圧縮・長さ制限を行う。
# head -c がマルチバイト文字の途中で切った場合の壊れたバイト列は iconv -c で落とす。
sanitize() {
    printf '%s' "$1" | tr '\n' ' ' | LC_ALL=C sed 's/  */ /g; s/^ *//; s/ *$//' | head -c "$2" | iconv -f UTF-8 -t UTF-8 -c 2>/dev/null || true
}

CWD="$(jq_get '.cwd')"
SESSION_ID="$(jq_get '.session_id')"
LAST_MESSAGE="$(jq_get '.last_assistant_message')"
TOOL_NAME="$(jq_get '.tool_name')"
TOOL_COMMAND="$(jq_get '.tool_input.command')"
TOOL_DESCRIPTION="$(jq_get '.tool_input.description')"

REPO="$(basename "${CWD:-unknown}")"
SHORT_SID="${SESSION_ID:0:8}"

TURN_FILE=""
if [[ $SESSION_ID =~ ^[[:alnum:]_-]+$ ]]; then
    TURN_FILE="${TMPDIR:-/tmp}/codex-turn-${SESSION_ID}"
fi

# UserPromptSubmit ではターン開始時刻の記録だけを行う。
# このイベントの stdout は追加コンテキストとして扱われるため、何も出力しない。
if [[ $EVENT == "turn_start" ]]; then
    if [[ -n $TURN_FILE ]]; then
        date +%s >"$TURN_FILE"
    fi
    exit 0
fi

case "$EVENT" in
stop)
    # 短時間で終わったターンは通知しない。開始時刻は turn_start が記録する。
    # 記録が無い場合 (セッション再開直後など) は通知する。
    if [[ -n $TURN_FILE && -f $TURN_FILE ]]; then
        STARTED_AT="$(cat "$TURN_FILE")"
        rm -f "$TURN_FILE"
        if [[ $STARTED_AT =~ ^[0-9]+$ ]] && (($(date +%s) - STARTED_AT < MIN_ELAPSED_SEC)); then
            exit 0
        fi
    fi
    TITLE="✅ Codex [${REPO}]${SHORT_SID:+ #${SHORT_SID}}"
    BODY="$(sanitize "$LAST_MESSAGE" 150)"
    BODY="${BODY:-次の指示を待っています}"
    ;;
permission)
    TITLE="🔐 Codex [${REPO}]${SHORT_SID:+ #${SHORT_SID}}"
    if [[ -n $TOOL_DESCRIPTION ]]; then
        BODY="$TOOL_DESCRIPTION"
    elif [[ -n $TOOL_NAME && -n $TOOL_COMMAND ]]; then
        BODY="${TOOL_NAME}: ${TOOL_COMMAND}"
    else
        BODY="${TOOL_NAME:-ツール実行}の許可を待っています"
    fi
    BODY="$(sanitize "$BODY" 150)"
    ;;
*)
    TITLE="Codex [${REPO}]"
    BODY="イベント: $EVENT"
    ;;
esac

~/.dotfiles/script/notify/notify.sh "$TITLE" "$BODY" "$SESSION_ID" codex >/dev/null 2>&1 || true
