#!/bin/bash

DOTPATH=$(cd "$(dirname "$0")/../.." && pwd)

brew install \
    coreutils \
    git \
    curl \
    wget \
    llvm \
    ninja \
    cmake \
    tree \
    subversion \
    mactop \
    htop

brew install vjeantet/tap/alerter

# Xcodeが入っているときのみインストール可能なのでinstallを分ける
brew install \
    swiftlint

brew install --cask \
    nikitabobko/tap/aerospace \
    alt-tab \
    balenaetcher \
    bettertouchtool \
    clipy \
    font-roboto-mono-nerd-font \
    ghostty \
    hammerspoon \
    inkscape \
    iterm2 \
    karabiner-elements \
    raycast \
    wezterm@nightly \
    xquartz \
    cursor \
    visual-studio-code \
    notion \
    obsidian \
    ollama-app \
    nani \
    deepl \
    chatgpt \
    claude \
    azookey \
    homerow

brew tap manaflow-ai/cmux
brew install --cask cmux

# AltTabの設定を反映
osascript -e 'quit app "AltTab"' >/dev/null 2>&1 || true
defaults import com.lwouis.alt-tab-macos "$DOTPATH/config/mac/com.lwouis.alt-tab-macos.plist"
killall cfprefsd >/dev/null 2>&1 || true
