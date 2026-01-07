#!/usr/bin/env bash
set -euo pipefail

# Notify script for desktop notifications
# - If running over SSH: emit OSC 777 (WezTerm toast notification) to the client terminal.
# - Otherwise: do OS-native notifications (macOS/Linux/Windows/WSL).
#
# Usage:
#   ./notify.sh "TITLE" "MESSAGE"
# Optional:
#   ./notify.sh --osc "TITLE" "MESSAGE"   # force OSC
#   ./notify.sh --native "TITLE" "MESSAGE" # force native (ignore SSH)

TITLE="Claude Code"
MESSAGE="Notification"
FORCE_MODE="auto"  # auto|osc|native

if [[ "${1:-}" == "--osc" ]]; then
  FORCE_MODE="osc"
  shift
elif [[ "${1:-}" == "--native" ]]; then
  FORCE_MODE="native"
  shift
fi

TITLE="${1:-$TITLE}"
MESSAGE="${2:-$MESSAGE}"

is_ssh() {
  [[ -n "${SSH_CONNECTION:-}" || -n "${SSH_CLIENT:-}" || -n "${SSH_TTY:-}" ]]
}

is_tty_stdout() {
  [[ -t 1 ]]
}

# OSC params are delimited by ';' and should avoid control chars.
sanitize_osc() {
  # 1) remove control chars except TAB
  # 2) replace ';' to avoid breaking params
  printf '%s' "$1" \
    | LC_ALL=C tr -d '\000-\010\013-\037\177' \
    | sed 's/;/,/g'
}

emit_osc_notification() {
  local t b
  t="$(sanitize_osc "$TITLE")"
  b="$(sanitize_osc "$MESSAGE")"

  # WezTerm supports:
  #   printf "\e]777;notify;%s;%s\e\\" "title" "body"
  # and also OSC 9 (body only) :contentReference[oaicite:2]{index=2}
  local seq
  seq="$(printf '\e]777;notify;%s;%s\e\\' "$t" "$b")"

  # If inside tmux, wrap in tmux passthrough so the outer terminal sees it.
  # Example pattern for OSC 777 passthrough in tmux: :contentReference[oaicite:3]{index=3}
  if [[ -n "${TMUX:-}" ]]; then
    seq="$(printf '\033Ptmux;\033%s\033\\' "$seq")"
  fi

  printf '%b' "$seq"
}

detect_os() {
  case "$(uname -s)" in
    Darwin*) echo "mac" ;;
    Linux*)
      if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

notify_mac() {
  osascript -e "display notification \"${MESSAGE}\" with title \"${TITLE}\""
}

notify_linux() {
  if command -v notify-send &>/dev/null; then
    notify-send "${TITLE}" "${MESSAGE}" --urgency=normal
  elif command -v zenity &>/dev/null; then
    zenity --notification --text="${TITLE}: ${MESSAGE}" >/dev/null 2>&1 &
  elif command -v kdialog &>/dev/null; then
    kdialog --passivepopup "${MESSAGE}" 5 --title "${TITLE}" >/dev/null 2>&1 &
  fi
}

notify_wsl() {
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
}

notify_windows() {
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
}

main() {
  # 1) Decide mode
  if [[ "$FORCE_MODE" == "osc" ]]; then
    if is_tty_stdout; then
      emit_osc_notification
    fi
    exit 0
  fi

  if [[ "$FORCE_MODE" == "auto" ]] && is_ssh && is_tty_stdout; then
    emit_osc_notification
    exit 0
  fi

  # 2) Native notifications
  if [[ "$FORCE_MODE" == "native" || "$FORCE_MODE" == "auto" ]]; then
    case "$(detect_os)" in
      mac) notify_mac ;;
      linux) notify_linux ;;
      wsl) notify_wsl ;;
      windows) notify_windows ;;
      *) : ;;
    esac
  fi
}

main "$@"
