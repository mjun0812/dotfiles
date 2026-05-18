#!/usr/bin/env bash
set -euo pipefail

# notify-claude-hook.sh
#
# Claude Code の hook (Notification / Stop / StopFailure / SessionEnd) から
# stdin で渡される JSON を読み、リポジトリ名・セッションID短縮・実メッセージ/
# 最終発話・エラー情報を含むリッチな通知を notify.sh 経由で送出する。
#
# Usage:
#   notify-claude-hook.sh <event>
#     event: notification | stop | stop_failure | session_end

EVENT="${1:-stop}"
INPUT="$(cat || true)"

jq_get() {
  printf '%s' "$INPUT" | jq -r "($1) // \"\"" 2>/dev/null || printf ''
}

CWD="$(jq_get '.cwd')"
SESSION_ID="$(jq_get '.session_id')"
TRANSCRIPT_PATH="$(jq_get '.transcript_path')"
MESSAGE="$(jq_get '.message')"
ERROR_TYPE="$(jq_get '.error_type')"
ERROR_MESSAGE="$(jq_get '.error_message')"
REASON="$(jq_get '.reason')"

REPO="$(basename "${CWD:-unknown}")"
SHORT_SID="${SESSION_ID:0:8}"

# transcript (JSONL) から最後の assistant の text content を抽出。失敗時は空。
last_assistant_text() {
  local path="$1"
  [[ -z "$path" || ! -f "$path" ]] && return 0
  jq -rs '
    [ .[] | select((.message.role // .role) == "assistant") ]
    | last
    | ((.message.content // .content)
       | if type == "array" then
           [ .[] | select(.type == "text") | .text ] | join(" ")
         elif type == "string" then .
         else "" end)
    // ""
  ' "$path" 2>/dev/null \
    | tr '\n' ' ' \
    | sed 's/  */ /g; s/^ *//; s/ *$//' \
    | head -c 160
}

case "$EVENT" in
  notification)
    TITLE="Claude Code [${REPO}]${SHORT_SID:+ #${SHORT_SID}}"
    BODY="${MESSAGE:-入力を待っています 📝}"
    ;;
  stop)
    TITLE="✅ Claude Code [${REPO}]${SHORT_SID:+ #${SHORT_SID}}"
    BODY="$(last_assistant_text "$TRANSCRIPT_PATH")"
    [[ -z "$BODY" ]] && BODY="タスクが完了しました"
    ;;
  stop_failure)
    TITLE="⚠️ Claude Code [${REPO}]${SHORT_SID:+ #${SHORT_SID}}"
    if [[ -n "$ERROR_TYPE" && -n "$ERROR_MESSAGE" ]]; then
      BODY="${ERROR_TYPE}: ${ERROR_MESSAGE}"
    elif [[ -n "$ERROR_TYPE" ]]; then
      BODY="API エラー: ${ERROR_TYPE}"
    elif [[ -n "$ERROR_MESSAGE" ]]; then
      BODY="${ERROR_MESSAGE}"
    else
      BODY="応答がエラーで打ち切られました"
    fi
    BODY="$(printf '%s' "$BODY" | tr '\n' ' ' | sed 's/  */ /g; s/^ *//; s/ *$//' | head -c 200)"
    ;;
  session_end)
    TITLE="⚠️ Claude Code [${REPO}]${SHORT_SID:+ #${SHORT_SID}}"
    BODY="bypass permissions が無効化されました${REASON:+ (${REASON})}"
    ;;
  *)
    TITLE="Claude Code [${REPO}]"
    BODY="${MESSAGE:-イベント: $EVENT}"
    ;;
esac

exec ~/.dotfiles/script/notify.sh --osc "$TITLE" "$BODY"
