#!/usr/bin/env bash
set -euo pipefail

# Notify script for desktop notifications
# - SSH sessions: emit OSC escape sequences to the client terminal
#   - OSC 777: WezTerm, VSCode, Cursor
#   - OSC 9: iTerm2
# - Local sessions: OS-native notifications (macOS/Linux/Windows/WSL)
#
# Usage:
#   ./notify.sh "TITLE" "MESSAGE"
#   ./notify.sh --osc "TITLE" "MESSAGE"      # force OSC, write to terminal/dev-tty
#   ./notify.sh --native "TITLE" "MESSAGE"   # force native (ignore SSH)
#   ./notify.sh --emit-osc "TITLE" "MESSAGE" # print raw OSC payload to stdout only
#                                            # (for Claude Code terminalSequence; no terminal/native output)

# Parse force mode flag
FORCE_MODE="auto"
case "${1:-}" in
--osc)
    FORCE_MODE="osc"
    shift
    ;;
--native)
    FORCE_MODE="native"
    shift
    ;;
--emit-osc)
    FORCE_MODE="emit"
    shift
    ;;
esac

TITLE="${1:-Claude Code}"
MESSAGE="${2:-Notification}"
SESSION_ID="${3:-}"

# Determine if we should use OSC notification
USE_OSC=$([[ $FORCE_MODE == "osc" || $FORCE_MODE == "emit" || ($FORCE_MODE == "auto" && (-n ${SSH_CONNECTION:-} || -n ${SSH_CLIENT:-} || -n ${SSH_TTY:-})) ]] && printf 'true' || printf 'false')

# Handle OSC notification
if [[ $USE_OSC == "true" ]]; then
    # Sanitize title and message: remove control chars and replace ';'
    SAFE_TITLE="$(printf '%s' "$TITLE" | LC_ALL=C tr -d '\000-\010\013-\037\177' | sed 's/;/,/g')"
    SAFE_MESSAGE="$(printf '%s' "$MESSAGE" | LC_ALL=C tr -d '\000-\010\013-\037\177' | sed 's/;/,/g')"

    # Detect client terminal to choose the correct OSC protocol
    OSC_KIND="777"
    if [[ -n ${ITERM_SESSION_ID:-} || ${TERM_PROGRAM:-} == "iTerm.app" ]]; then
        OSC_KIND="9"
    elif [[ -n ${WEZTERM_PANE:-} || ${TERM_PROGRAM:-} == "WezTerm" ]]; then
        OSC_KIND="777"
    elif [[ ${TERM_PROGRAM:-} == "vscode" || -n ${VSCODE_IPC_HOOK_CLI:-} || -n ${VSCODE_PID:-} ]]; then
        OSC_KIND="777"
    elif [[ ${TERM_PROGRAM:-} == "cursor" || -n ${CURSOR_IPC_HOOK_CLI:-} || -n ${CURSOR_TRACE_ID:-} ]]; then
        OSC_KIND="777"
    fi

    # Build OSC sequence
    # OSC 777: WezTerm, VSCode, Cursor (supports title + body)
    # OSC 9: iTerm2 (single message only, combine title and body)
    if [[ $OSC_KIND == "9" ]]; then
        OSC_PAYLOAD="$(printf '\e]9;%s: %s\a' "$SAFE_TITLE" "$SAFE_MESSAGE")"
    else
        OSC_PAYLOAD="$(printf '\e]777;notify;%s;%s\e\\' "$SAFE_TITLE" "$SAFE_MESSAGE")"
    fi

    # Wrap in tmux passthrough if inside tmux
    if [[ -n ${TMUX:-} ]]; then
        OSC_PAYLOAD="$(printf '\033Ptmux;\033%s\033\\' "$OSC_PAYLOAD")"
    fi

    # In emit mode, print the raw OSC payload to stdout only and exit. The caller
    # (notify-claude-hook.sh) wraps it into a Claude Code terminalSequence so that
    # Claude Code itself writes the sequence to the terminal. Do not write to the
    # terminal directly nor fall back to native notifications here.
    if [[ $FORCE_MODE == "emit" ]]; then
        printf '%b' "$OSC_PAYLOAD"
        exit 0
    fi

    # Determine output target. Fall through to native notifications if OSC cannot be delivered.
    if [[ -t 1 ]]; then
        printf '%b' "$OSC_PAYLOAD" && exit 0
    elif [[ -e /dev/tty ]] && printf '%b' "$OSC_PAYLOAD" 2>/dev/null >/dev/tty; then
        exit 0
    fi
fi

# ################ Native notification ################
# detect OS
OS_TYPE="unknown"
case "$(uname -s)" in
Darwin*)
    OS_TYPE="mac"
    ;;
Linux*)
    if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null; then
        OS_TYPE="wsl"
    else
        OS_TYPE="linux"
    fi
    ;;
MINGW* | MSYS* | CYGWIN*)
    OS_TYPE="windows"
    ;;
esac

# Send native notification based on OS
case "$OS_TYPE" in
mac)
    PANE_ID="${WEZTERM_PANE:-}"
    if [[ -z $PANE_ID && ${TERM_PROGRAM:-} == "WezTerm" ]] && command -v wezterm >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        CURRENT_TTY="$(ps -o tty= -p "$PPID" 2>/dev/null | tr -d ' ')"
        if [[ -n $CURRENT_TTY && $CURRENT_TTY != "??" ]]; then
            [[ $CURRENT_TTY == /dev/* ]] || CURRENT_TTY="/dev/$CURRENT_TTY"
            PANE_ID="$(wezterm cli list --format json 2>/dev/null | jq -r --arg tty "$CURRENT_TTY" 'first(.[] | select(.tty_name == $tty) | .pane_id) // empty' 2>/dev/null || true)"
        fi
    fi

    ALERTER_BIN="$(command -v alerter || true)"
    if [[ -z $ALERTER_BIN ]]; then
        for candidate in /opt/homebrew/bin/alerter /usr/local/bin/alerter; do
            if [[ -x $candidate ]]; then
                ALERTER_BIN="$candidate"
                break
            fi
        done
    fi

    if [[ $PANE_ID =~ ^[0-9]+$ && $SESSION_ID =~ ^[[:alnum:]_-]+$ ]] && command -v open >/dev/null 2>&1; then
        nohup open -g "hammerspoon://claude-wezterm-capture?session=${SESSION_ID}&pane=${PANE_ID}" \
            >/dev/null 2>&1 </dev/null &
    fi

    if [[ $PANE_ID =~ ^[0-9]+$ && -n $SESSION_ID && -n $ALERTER_BIN ]]; then
        nohup "$HOME/.dotfiles/script/wezterm/alerter-wezterm-notify.sh" "$TITLE" "$MESSAGE" "$PANE_ID" "$SESSION_ID" \
            >/dev/null 2>&1 </dev/null &
    else
        osascript -e "display notification \"${MESSAGE}\" with title \"${TITLE}\""
    fi
    ;;
linux)
    if command -v notify-send &>/dev/null; then
        notify-send "${TITLE}" "${MESSAGE}" --urgency=normal
    elif command -v zenity &>/dev/null; then
        zenity --notification --text="${TITLE}: ${MESSAGE}" &>/dev/null &
    elif command -v kdialog &>/dev/null; then
        kdialog --passivepopup "${MESSAGE}" 5 --title "${TITLE}" &>/dev/null &
    fi
    ;;
wsl)
    if command -v powershell.exe &>/dev/null; then
        powershell.exe -Command "
        [windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
        \$template = '<toast><visual><binding template=\"ToastText02\"><text id=\"1\">${TITLE}</text><text id=\"2\">${MESSAGE}</text></binding></visual></toast>'
        \$xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
        \$xml.LoadXml(\$template)
        \$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show(\$toast)
      " 2>/dev/null || true
    fi
    ;;
windows)
    if command -v powershell &>/dev/null; then
        powershell -Command "
        Add-Type -AssemblyName System.Windows.Forms
        \$balloon = New-Object System.Windows.Forms.NotifyIcon
        \$balloon.Icon = [System.Drawing.SystemIcons]::Information
        \$balloon.BalloonTipTitle = '${TITLE}'
        \$balloon.BalloonTipText = '${MESSAGE}'
        \$balloon.Visible = \$true
        \$balloon.ShowBalloonTip(5000)
        Start-Sleep -Seconds 1
        \$balloon.Dispose()
      " 2>/dev/null || true
    elif command -v msg &>/dev/null; then
        msg "%username%" "${TITLE}: ${MESSAGE}" 2>/dev/null || true
    fi
    ;;
esac
