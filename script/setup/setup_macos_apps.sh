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
# - karabiner-elements / xquartz / azookey: .pkg installer が非対話 sudo を要求する
# - mactex-no-gui: pkg installer choices が未サポート (加えて sudo も要求する)
# - raycast: url が拡張子なしの dmg (releases.raycast.com/.../download?build=arm) で、
#   mise が展開できず app artifact 'Raycast.app' was not found になる
# - nikitabobko/tap/aerospace / ci7lus/miraktest/miraktest: tap 側が Homebrew API メタデータを公開していない
CASKS=(
    nikitabobko/tap/aerospace
    ci7lus/miraktest/miraktest
    karabiner-elements
    mactex-no-gui
    raycast
    xquartz
    azookey
)
for cask in "${CASKS[@]}"; do
    install_cask "$cask"
done

# dotfiles の plist から各 app の設定を反映
# (Clipy のスニペット本体は Realm DB のため対象外)
APP_DEFAULTS=(
    "AltTab:com.lwouis.alt-tab-macos"
    "BetterDisplay:pro.betterdisplay.BetterDisplay"
    "Homerow:com.superultra.Homerow"
    "Clipy:com.clipy-app.Clipy"
)
for entry in "${APP_DEFAULTS[@]}"; do
    app="${entry%%:*}"
    domain="${entry#*:}"
    osascript -e "quit app \"$app\"" >/dev/null 2>&1 || true
    defaults import "$domain" "$DOTPATH/config/mac/$domain.plist"
done
killall cfprefsd >/dev/null 2>&1 || true

# iTerm2 は custom folder (repo 内) から設定を読み書きする
defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$DOTPATH/config/mac/iterm2"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
# 終了時に確認せず常に custom folder へ保存する (selection: 0 = on quit, 1 = never, 2 = always)
defaults write com.googlecode.iterm2 NoSyncNeverRemindPrefsChangesLostForFile -bool true
defaults write com.googlecode.iterm2 NoSyncNeverRemindPrefsChangesLostForFile_selection -int 2

# karabiner-elements の設定を symlink で配置
mkdir -p "$DOTPATH/.backup"
cp -aLf "$HOME/.config/karabiner" "$DOTPATH/.backup/karabiner" 2>/dev/null || true
rm -rf "$HOME/.config/karabiner"
ln -snfv "$DOTPATH/config/mac/karabiner" "$HOME/.config/karabiner"
