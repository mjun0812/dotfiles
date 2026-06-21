#!/usr/bin/env zsh

log_section() {
    print -P "%F{blue}%B==> %f%b%F{white}%B$1%f%b"
}

DOTPATH=$(cd $(dirname $0)/.. && pwd)
LAUNCHD_SOURCE_DIR="$DOTPATH/config/mac/launchd"
LAUNCHD_TARGET_DIR="$HOME/Library/LaunchAgents"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "launchd setup is macOS only; skipping"
    exit 0
fi

log_section "Setting up launchd agents..."
mkdir -p "$LAUNCHD_TARGET_DIR"
mkdir -p "$DOTPATH/.backup/LaunchAgents"

for plist in "$LAUNCHD_SOURCE_DIR"/*.plist(N); do
    label=$(basename "$plist" .plist)
    target="$LAUNCHD_TARGET_DIR/$(basename "$plist")"

    # Unload existing agent so we can replace its plist
    if launchctl list | grep -q "$label"; then
        launchctl unload "$target" 2>/dev/null || true
    fi

    cp -aLf "$target" "$DOTPATH/.backup/LaunchAgents/$(basename "$plist")" 2>/dev/null || true
    rm -f "$target"
    ln -snfv "$plist" "$target"

    launchctl load "$target"
    echo "loaded: $label"
done
