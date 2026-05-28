#!/bin/bash

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
    htop \
    neofetch

# Xcodeが入っているときのみインストール可能
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
