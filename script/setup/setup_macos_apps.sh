#!/bin/bash

DOTPATH=$(cd "$(dirname "$0")/../.." && pwd)

# miseのdefaultsで宣言できないappの設定を、dotfilesのplistから反映する
# (他のappは config.macos.toml の [bootstrap.macos.defaults]。Clipy のスニペット本体は Realm DB のため対象外)
APP_DEFAULTS=(
    "BetterDisplay:pro.betterdisplay.BetterDisplay"
    "Clipy:com.clipy-app.Clipy"
)
for entry in "${APP_DEFAULTS[@]}"; do
    app="${entry%%:*}"
    domain="${entry#*:}"
    osascript -e "quit app \"$app\"" >/dev/null 2>&1 || true
    defaults import "$domain" "$DOTPATH/config/mac/$domain.plist"
done
killall cfprefsd >/dev/null 2>&1 || true

# karabiner-elements の設定を symlink で配置
mkdir -p "$DOTPATH/.backup"
cp -aLf "$HOME/.config/karabiner" "$DOTPATH/.backup/karabiner" 2>/dev/null || true
rm -rf "$HOME/.config/karabiner"
ln -snfv "$DOTPATH/config/mac/karabiner" "$HOME/.config/karabiner"
