#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title WezTerm: New Window
# @raycast.mode silent
# @raycast.packageName WezTerm
# @raycast.icon 🖥️

set -euo pipefail

# Open a new WezTerm window
/opt/homebrew/bin/wezterm start &

echo "Opened WezTerm window"
