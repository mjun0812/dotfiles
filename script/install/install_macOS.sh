#!/bin/bash

DOTPATH=$(cd "$(dirname "$0")/../.." && pwd)

# mise bootstrap で解決できない tap 側の formula/cask
brew install vjeantet/tap/alerter

brew install --cask \
    nikitabobko/tap/aerospace \
    balenaetcher \
    clipy \
    ghostty \
    inkscape \
    karabiner-elements \
    raycast \
    wezterm@nightly \
    xquartz \
    notion \
    obsidian \
    nani \
    deepl \
    claude \
    azookey

brew tap manaflow-ai/cmux
brew trust manaflow-ai/cmux
brew install --cask cmux

# AltTabの設定を反映
osascript -e 'quit app "AltTab"' >/dev/null 2>&1 || true
defaults import com.lwouis.alt-tab-macos "$DOTPATH/config/mac/com.lwouis.alt-tab-macos.plist"
killall cfprefsd >/dev/null 2>&1 || true
