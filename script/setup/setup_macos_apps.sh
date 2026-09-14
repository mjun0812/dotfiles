#!/bin/bash

DOTPATH=$(cd "$(dirname "$0")/../.." && pwd)

# mise does not support MacTeX's pkg installer choices.
if ! brew list --cask mactex-no-gui >/dev/null 2>&1; then
    brew install --cask mactex-no-gui || exit
fi

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
