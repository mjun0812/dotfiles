#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Chrome: New Window in Current Space
# @raycast.mode silent
# @raycast.packageName Google Chrome
# @raycast.icon 🌐

set -euo pipefail

/usr/bin/osascript <<'APPLESCRIPT'
tell application "Google Chrome"
  make new window
  activate
end tell
APPLESCRIPT

echo "Opened Chrome window"
