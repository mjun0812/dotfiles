#!/bin/bash

DOTPATH=$(cd "$(dirname "$0")/../.." && pwd)

install_cask() {
    local pkg="$1"
    local name="${pkg##*/}"
    if brew list --cask "$name" >/dev/null 2>&1; then
        return 0
    fi
    local log
    log=$(brew install --cask "$pkg" 2>&1)
    echo "$log"
    # 既存の非brew管理 .app がある場合は --force で adopt する
    if echo "$log" | grep -q "already an App at"; then
        brew install --cask --force "$pkg"
    fi
}

# mise bootstrap で解決できない tap 側の formula
brew list --formula alerter >/dev/null 2>&1 || brew install vjeantet/tap/alerter

# mise bootstrap で解決できない cask
CASKS=(
    nikitabobko/tap/aerospace
    balenaetcher
    clipy
    ghostty
    inkscape
    karabiner-elements
    raycast
    wezterm@nightly
    xquartz
    notion
    obsidian
    nani
    deepl
    claude
    azookey
)
for cask in "${CASKS[@]}"; do
    install_cask "$cask"
done

# manaflow-ai/cmux tap のみ登録 (cask 本体は未使用)
brew tap manaflow-ai/cmux >/dev/null 2>&1 || true
brew trust manaflow-ai/cmux >/dev/null 2>&1 || true

# AltTab の設定を反映
osascript -e 'quit app "AltTab"' >/dev/null 2>&1 || true
defaults import com.lwouis.alt-tab-macos "$DOTPATH/config/mac/com.lwouis.alt-tab-macos.plist"
killall cfprefsd >/dev/null 2>&1 || true
