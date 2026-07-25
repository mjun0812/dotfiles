#!/usr/bin/env bash
set -euo pipefail

# notify-claude-hook.sh
#
# Claude Code の hook (UserPromptSubmit / Notification / Stop / StopFailure) から
# stdin で渡される JSON を読み、リポジトリ名・セッションID短縮・実メッセージ/
# エラー情報を含むリッチな通知を notify.sh 経由で送出する。
#
# Usage:
#   notify-claude-hook.sh <event>
#     event: turn_start | notification | stop | stop_failure

# 応答がこの秒数未満で終わったターンでは stop の通知を出さない。
MIN_ELAPSED_SEC=60

EVENT="${1:-notification}"
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
MESSAGE="$(jq_get '.message')"
NOTIFICATION_TYPE="$(jq_get '.notification_type')"
LAST_MESSAGE="$(jq_get '.last_assistant_message')"
ERROR_TYPE="$(jq_get '.error_type')"
ERROR_MESSAGE="$(jq_get '.error_message')"

REPO="$(basename "${CWD:-unknown}")"
SHORT_SID="${SESSION_ID:0:8}"

TURN_FILE=""
if [[ $SESSION_ID =~ ^[[:alnum:]_-]+$ ]]; then
    TURN_FILE="${TMPDIR:-/tmp}/claude-turn-${SESSION_ID}"
fi

# UserPromptSubmit ではターン開始時刻の記録だけを行う。
# このイベントの stdout はプロンプトへの追加コンテキストとして扱われるため、何も出力しない。
if [[ $EVENT == "turn_start" ]]; then
    if [[ -n $TURN_FILE ]]; then
        date +%s >"$TURN_FILE"
    fi
    exit 0
fi

case "$EVENT" in
notification)
    case "$NOTIFICATION_TYPE" in
    permission_prompt)
        ICON="🔐"
        DEFAULT_BODY="許可を待っています"
        ;;
    idle_prompt)
        ICON="📝"
        DEFAULT_BODY="入力を待っています"
        ;;
    agent_needs_input)
        ICON="🤖"
        DEFAULT_BODY="subagent が入力を待っています"
        ;;
    *)
        ICON="🔔"
        DEFAULT_BODY="通知があります"
        ;;
    esac
    TITLE="${ICON} Claude Code [${REPO}]${SHORT_SID:+ #${SHORT_SID}}"
    BODY="$(sanitize "$MESSAGE" 150)"
    BODY="${BODY:-$DEFAULT_BODY}"
    ;;
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
    TITLE="✅ Claude Code [${REPO}]${SHORT_SID:+ #${SHORT_SID}}"
    BODY="$(sanitize "$LAST_MESSAGE" 150)"
    BODY="${BODY:-次の指示を待っています}"
    ;;
stop_failure)
    TITLE="⚠️ Claude Code [${REPO}]${SHORT_SID:+ #${SHORT_SID}}"
    if [[ -n $ERROR_TYPE && -n $ERROR_MESSAGE ]]; then
        BODY="${ERROR_TYPE}: ${ERROR_MESSAGE}"
    elif [[ -n $ERROR_TYPE ]]; then
        BODY="API エラー: ${ERROR_TYPE}"
    elif [[ -n $ERROR_MESSAGE ]]; then
        BODY="${ERROR_MESSAGE}"
    else
        BODY="応答がエラーで打ち切られました"
    fi
    BODY="$(sanitize "$BODY" 200)"
    ;;
*)
    TITLE="Claude Code [${REPO}]"
    BODY="${MESSAGE:-イベント: $EVENT}"
    ;;
esac

# Claude Code hookはTTYを持たないため、ローカルmacOSではalerterを直接起動する。
# セッション開始時にHammerspoonへ保存したWezTerm windowへ、通知クリックで戻る。
if [[ $(uname -s) == Darwin* && -z ${SSH_CONNECTION:-} && -z ${SSH_CLIENT:-} && -z ${SSH_TTY:-} ]]; then
    ~/.dotfiles/script/notify.sh --native "$TITLE" "$BODY" "$SESSION_ID" ~/.dotfiles/assets/notify-claude.png >/dev/null 2>&1 || true
    exit 0
fi

# OSC 通知ペイロード(OSC 9/777 判定・サニタイズ・tmux パススルー込み)を生成する。
# hook の子プロセスの stdout は TTY に繋がっておらず、OSC を直接書いても届かないため、
# Claude Code の hook 出力プロトコルである terminalSequence JSON として返し、
# TTY に直結した Claude Code 本体にターミナルへ送出させる。
# (Claude Code がサポートする terminalSequence は OSC 0/1/2/9/99/777 と BEL のみ)
SEQ="$(~/.dotfiles/script/notify.sh --emit-osc "$TITLE" "$BODY" 2>/dev/null || true)"

# ペイロードが空なら何も出力せず正常終了する(hook を失敗させない)。
[[ -z $SEQ ]] && exit 0

# jq の --arg で制御文字を含む値も安全に JSON エスケープされる。
jq -n --arg seq "$SEQ" '{terminalSequence: $seq}'
