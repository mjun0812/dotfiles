#!/bin/bash

set -u -o pipefail

DOTPATH=$(cd "$(dirname "$0")/../.." && pwd)
MAC_CONFIG_DIR="$DOTPATH/config/mac"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This script supports macOS only."
    exit 1
fi

dump_defaults() {
    local domain="$1"
    local output="$2"

    # defaults export は存在しないdomainでも空のplistを返すため、先に存在を確かめる
    if defaults read "$domain" >/dev/null 2>&1 &&
        defaults export "$domain" - | python3 "$DOTPATH/script/tools/mac_defaults.py" strip "$domain" >"$output.tmp"; then
        mv "$output.tmp" "$output"
        echo "Dumped $domain to $output"
    else
        rm -f "$output.tmp"
        echo "Skipped $domain: defaults domain not found"
    fi
}

# 設定をmiseのdefaultsで宣言できないappだけをplistで扱う (宣言しているappのずれはupdate.shが報告する)
dump_defaults "pro.betterdisplay.BetterDisplay" "$MAC_CONFIG_DIR/pro.betterdisplay.BetterDisplay.plist"
dump_defaults "com.clipy-app.Clipy" "$MAC_CONFIG_DIR/com.clipy-app.Clipy.plist"
