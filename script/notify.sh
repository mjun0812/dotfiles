#!/usr/bin/env bash
set -euo pipefail

# Notify script for desktop notifications
# - SSH sessions: emit OSC 777 (WezTerm toast notification) to the client terminal
# - Local sessions: OS-native notifications (macOS/Linux/Windows/WSL)
#
# Usage:
#   ./notify.sh "TITLE" "MESSAGE"
#   ./notify.sh --osc "TITLE" "MESSAGE"    # force OSC
#   ./notify.sh --native "TITLE" "MESSAGE" # force native (ignore SSH)

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

is_ssh() {
  [[ -n "${SSH_CONNECTION:-}" || -n "${SSH_CLIENT:-}" || -n "${SSH_TTY:-}" ]]
}

sanitize_osc() {
  # Remove control chars (except TAB) and replace ';' to avoid breaking OSC params
  printf '%s' "$1" | LC_ALL=C tr -d '\000-\010\013-\037\177' | sed 's/;/,/g'
}

emit_osc_notification() {
  local title body seq output_target
  title="$(sanitize_osc "$TITLE")"
  body="$(sanitize_osc "$MESSAGE")"
  seq="$(printf '\e]777;notify;%s;%s\e\\' "$title" "$body")"

  # Wrap in tmux passthrough if inside tmux
  if [[ -n "${TMUX:-}" ]]; then
    seq="$(printf '\033Ptmux;\033%s\033\\' "$seq")"
  fi

  # Determine output target: use /dev/tty if stdout is not a TTY
  if [[ -t 1 ]]; then
    output_target="/dev/stdout"
  elif [[ -e /dev/tty ]]; then
    output_target="/dev/tty"
  else
    return 1  # No TTY available
  fi

  printf '%b' "$seq" > "$output_target"
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
    MINGW* | MSYS* | CYGWIN*) echo "windows" ;;
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
    zenity --notification --text="${TITLE}: ${MESSAGE}" &>/dev/null &
  elif command -v kdialog &>/dev/null; then
    kdialog --passivepopup "${MESSAGE}" 5 --title "${TITLE}" &>/dev/null &
  fi
}

notify_wsl() {
  command -v powershell.exe &>/dev/null || return 0
  powershell.exe -Command "
    [windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
    \$template = '<toast><visual><binding template=\"ToastText02\"><text id=\"1\">${TITLE}</text><text id=\"2\">${MESSAGE}</text></binding></visual></toast>'
    \$xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
    \$xml.LoadXml(\$template)
    \$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show(\$toast)
  " 2>/dev/null || true
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

notify_native() {
  case "$(detect_os)" in
    mac) notify_mac ;;
    linux) notify_linux ;;
    wsl) notify_wsl ;;
    windows) notify_windows ;;
  esac
}

has_tty_access() {
  # Check if stdout is a TTY or /dev/tty is available
  [[ -t 1 ]] || [[ -e /dev/tty ]]
}

main() {
  # OSC mode: emit if TTY is available
  if [[ "$FORCE_MODE" == "osc" ]]; then
    has_tty_access && emit_osc_notification
    return
  fi

  # Auto mode: use OSC for SSH sessions with TTY access
  if [[ "$FORCE_MODE" == "auto" ]] && is_ssh && has_tty_access; then
    emit_osc_notification
    return
  fi

  # Native mode or auto mode (non-SSH)
  notify_native
}

main
