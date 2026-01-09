#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Safari: New Window in Current Space
# @raycast.mode silent
# @raycast.packageName Safari
# @raycast.icon 🌐

set -euo pipefail

/usr/bin/osascript <<'APPLESCRIPT'
tell application "Safari"
  make new document
  activate
end tell
APPLESCRIPT

# Raycast HUD/toast 用（silent は最後の1行がHUD表示） [oai_citation:2‡Gitee](https://gitee.com/typesugar_chenchao/script-commands?utm_source=chatgpt.com)
echo "Opened Safari window"