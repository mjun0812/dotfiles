#!/usr/bin/env zsh
#
# ローカルのapp設定をdotfilesへ逆同期する (install.shの対)。
# VSCode拡張リストとMozkey設定を書き出し、macOSのapp設定はmiseの宣言とのずれを報告する。commitは行わない。

log_section() {
    print -P "%F{blue}%B==> %f%b%F{white}%B$1%f%b"
}

DOTPATH=$(cd $(dirname $0) && pwd)

if [ "$(uname -s)" = "Darwin" ]; then
    if [ -f "$HOME/Library/Application Support/Mozc/config1.db" ]; then
        log_section "Saving Mozkey settings..."
        cp "$HOME/Library/Application Support/Mozc/config1.db" "$DOTPATH/config/mac/mozkey/config1.db" || exit 1
    fi

    log_section "Drift from [bootstrap.settings.macos.defaults] (update conf.d/macos-defaults.macos.toml by hand):"
    python3 "$DOTPATH/script/tools/mac_defaults.py"
fi

$DOTPATH/script/tools/dump_vscode_extensions.sh

log_section "Changes in dotfiles:"
git -C "$DOTPATH" status --short
