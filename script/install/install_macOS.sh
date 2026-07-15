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

# mise bootstrap で解決できない cask (mise の brew-cask shim では扱えないもの)
# - inkscape: cask DSL の version.csv.second が未サポート
# - karabiner-elements / xquartz / azookey: .pkg installer が非対話 sudo を要求する
# - mactex-no-gui: pkg installer choices が未サポート
# - raycast: cask shim が Raycast.app を検出できない
# - wezterm@nightly: cask 内の bash_completion DSL が未サポート
# - betterdisplay: cask 内の auto_updates DSL が未サポート
# - nikitabobko/tap/aerospace / ci7lus/miraktest/miraktest: tap 側が Homebrew API メタデータを公開していない
CASKS=(
    nikitabobko/tap/aerospace
    ci7lus/miraktest/miraktest
    betterdisplay
    inkscape
    karabiner-elements
    mactex-no-gui
    raycast
    wezterm@nightly
    xquartz
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
