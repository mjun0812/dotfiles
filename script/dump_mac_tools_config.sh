#!/bin/bash

set -u

DOTPATH=$(cd "$(dirname "$0")/.." && pwd)
MAC_CONFIG_DIR="$DOTPATH/config/mac"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This script supports macOS only."
    exit 1
fi

dump_defaults() {
    local domain="$1"
    local output="$2"

    if defaults export "$domain" "$output" 2>/dev/null; then
        plutil -convert xml1 "$output"
        echo "Dumped $domain to $output"
    else
        echo "Skipped $domain: defaults domain not found"
    fi
}

dump_defaults "com.lwouis.alt-tab-macos" "$MAC_CONFIG_DIR/com.lwouis.alt-tab-macos.plist"
dump_defaults "com.googlecode.iterm2" "$MAC_CONFIG_DIR/com.googlecode.iterm2.plist"
