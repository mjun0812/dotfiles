#!/usr/bin/env zsh
# Move the focused window to the next managed display, then focus it.
# Rift v0.7.1 CLI. Cycle by macOS X coordinate, then Y, then UUID.
set -euo pipefail
export PATH="${PATH:-/usr/bin:/bin}:/opt/homebrew/bin:/usr/local/bin"

for tool in rift-cli jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Missing command: %s\n' "$tool" >&2
        exit 1
    fi
done

script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
target="$(rift-cli query displays | jq -er -f "$script_dir/next-display.jq")"
[ -n "$target" ] || exit 0

# Do not change focus if the move failed (for example, after a disconnect).
rift-cli execute display move-window --uuid "$target" >/dev/null
rift-cli execute display focus --uuid "$target" >/dev/null
