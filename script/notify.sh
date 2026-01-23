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
#   ./notify.sh --osc "TITLE" "MESSAGE"    # force OSC
#   ./notify.sh --native "TITLE" "MESSAGE" # force native (ignore SSH)

# Parse force mode flag
FORCE_MODE="auto"
if [[ "${1:-}" == "--osc" ]]; then
  FORCE_MODE="osc"
  shift
elif [[ "${1:-}" == "--native" ]]; then
  FORCE_MODE="native"
  shift
fi

TITLE="${1:-Claude Code}"
MESSAGE="${2:-Notification}"

# Determine if we should use OSC notification
USE_OSC=false

if [[ "$FORCE_MODE" == "osc" ]]; then
  USE_OSC=true
elif [[ "$FORCE_MODE" == "auto" ]]; then
  # Auto mode: use OSC for SSH sessions
  if [[ -n "${SSH_CONNECTION:-}" || -n "${SSH_CLIENT:-}" || -n "${SSH_TTY:-}" ]]; then
    USE_OSC=true
  fi
fi

# Handle OSC notification
if [[ "$USE_OSC" == "true" ]]; then
  # Check TTY access
  [[ -t 1 ]] || [[ -e /dev/tty ]] || exit 0

  # Sanitize title and message: remove control chars and replace ';'
  SAFE_TITLE="$(printf '%s' "$TITLE" | LC_ALL=C tr -d '\000-\010\013-\037\177' | sed 's/;/,/g')"
  SAFE_MESSAGE="$(printf '%s' "$MESSAGE" | LC_ALL=C tr -d '\000-\010\013-\037\177' | sed 's/;/,/g')"

  # Build OSC sequences
  # OSC 777: WezTerm, VSCode, Cursor (supports title + body)
  OSC_777="$(printf '\e]777;notify;%s;%s\e\\' "$SAFE_TITLE" "$SAFE_MESSAGE")"
  # OSC 9: iTerm2 (single message only, combine title and body)
  OSC_9="$(printf '\e]9;%s: %s\a' "$SAFE_TITLE" "$SAFE_MESSAGE")"

  # Wrap in tmux passthrough if inside tmux
  if [[ -n "${TMUX:-}" ]]; then
    OSC_777="$(printf '\033Ptmux;\033%s\033\\' "$OSC_777")"
    OSC_9="$(printf '\033Ptmux;\033%s\033\\' "$OSC_9")"
  fi

  # Determine output target
  if [[ -t 1 ]]; then
    printf '%b' "$OSC_777"
    printf '%b' "$OSC_9"
  else
    printf '%b' "$OSC_777" > /dev/tty
    printf '%b' "$OSC_9" > /dev/tty
  fi

  exit 0
fi

# Native notification: detect OS
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
    osascript -e "display notification \"${MESSAGE}\" with title \"${TITLE}\""
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
