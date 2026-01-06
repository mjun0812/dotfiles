#!/bin/bash
# Notify script for desktop notifications
# Mac, Windows (WSL/Git Bash), Linux
#
# Usage: ./notify.sh "TITLE" "MESSAGE"
# Example: ./notify.sh "Claude Code" "Finished processing"

TITLE="${1:-Claude Code}"
MESSAGE="${2:-Notification}"

detect_os() {
    case "$(uname -s)" in
        Darwin*)
            echo "mac"
            ;;
        Linux*)
            # Detect WSL
            if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

notify_mac() {
    osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\""
}

notify_linux() {
    if command -v notify-send &>/dev/null; then
        notify-send "$TITLE" "$MESSAGE" --urgency=normal
    elif command -v zenity &>/dev/null; then
        zenity --notification --text="$TITLE: $MESSAGE" &
    elif command -v kdialog &>/dev/null; then
        kdialog --passivepopup "$MESSAGE" 5 --title "$TITLE"
    fi
}

notify_wsl() {
    if command -v powershell.exe &>/dev/null; then
        powershell.exe -Command "
            [windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
            [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
            \$template = '<toast><visual><binding template=\"ToastText02\"><text id=\"1\">$TITLE</text><text id=\"2\">$MESSAGE</text></binding></visual></toast>'
            \$xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
            \$xml.LoadXml(\$template)
            \$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
            [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show(\$toast)
        " 2>/dev/null
        
        # fallback to MessageBox if Toast fails
        if [ $? -ne 0 ]; then
            powershell.exe -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('$MESSAGE', '$TITLE', 'OK', 'Information')" 2>/dev/null &
        fi
    fi
}

notify_windows() {
    if command -v powershell &>/dev/null; then
        powershell -Command "
            Add-Type -AssemblyName System.Windows.Forms
            \$balloon = New-Object System.Windows.Forms.NotifyIcon
            \$balloon.Icon = [System.Drawing.SystemIcons]::Information
            \$balloon.BalloonTipTitle = '$TITLE'
            \$balloon.BalloonTipText = '$MESSAGE'
            \$balloon.Visible = \$true
            \$balloon.ShowBalloonTip(5000)
            Start-Sleep -Seconds 1
            \$balloon.Dispose()
        " 2>/dev/null
    elif command -v msg &>/dev/null; then
        msg "%username%" "$TITLE: $MESSAGE" 2>/dev/null
    fi
}

OS=$(detect_os)

case "$OS" in
    mac)
        notify_mac
        ;;
    linux)
        notify_linux
        ;;
    wsl)
        notify_wsl
        ;;
    windows)
        notify_windows
        ;;
esac
