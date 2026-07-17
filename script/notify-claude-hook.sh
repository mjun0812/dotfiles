#!/usr/bin/env bash
set -euo pipefail

# notify-claude-hook.sh
#
# Claude Code の hook (Notification / Stop / StopFailure) から
# stdin で渡される JSON を読み、リポジトリ名・セッションID短縮・実メッセージ/
# エラー情報を含むリッチな通知を notify.sh 経由で送出する。
#
# Usage:
#   notify-claude-hook.sh <event>
#     event: notification | stop | stop_failure

EVENT="${1:-notification}"
INPUT="$(cat || true)"

jq_get() {
    printf '%s' "$INPUT" | jq -r "($1) // \"\"" 2>/dev/null || printf ''
}

CWD="$(jq_get '.cwd')"
SESSION_ID="$(jq_get '.session_id')"
MESSAGE="$(jq_get '.message')"
ERROR_TYPE="$(jq_get '.error_type')"
ERROR_MESSAGE="$(jq_get '.error_message')"

REPO="$(basename "${CWD:-unknown}")"
SHORT_SID="${SESSION_ID:0:8}"

case "$EVENT" in
notification)
    TITLE="Claude Code [${REPO}]${SHORT_SID:+ #${SHORT_SID}}"
    BODY="${MESSAGE:-入力を待っています 📝}"
    ;;
stop)
    TITLE="✅ Claude Code [${REPO}]${SHORT_SID:+ #${SHORT_SID}}"
    BODY="次の指示を待っています"
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
    BODY="$(printf '%s' "$BODY" | tr '\n' ' ' | LC_ALL=C sed 's/  */ /g; s/^ *//; s/ *$//' | head -c 200 | iconv -f UTF-8 -t UTF-8 -c 2>/dev/null || true)"
    ;;
*)
    TITLE="Claude Code [${REPO}]"
    BODY="${MESSAGE:-イベント: $EVENT}"
    ;;
esac

# Claude Code hookはTTYを持たないため、ローカルmacOSではalerterを直接起動する。
# セッション開始時にHammerspoonへ保存したWezTerm windowへ、通知クリックで戻る。
if [[ $(uname -s) == Darwin* && -z ${SSH_CONNECTION:-} && -z ${SSH_CLIENT:-} && -z ${SSH_TTY:-} ]]; then
    ~/.dotfiles/script/notify.sh --native "$TITLE" "$BODY" "$SESSION_ID" >/dev/null 2>&1 || true
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
