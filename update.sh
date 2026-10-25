#!/usr/bin/env zsh
#
# ローカルの app 設定を dotfiles へ逆同期する (install.sh の対)。
# dump 後に repo へ生じた差分を表示する。commit は行わない。

log_section() {
    print -P "%F{blue}%B==> %f%b%F{white}%B$1%f%b"
}

DOTPATH=$(cd $(dirname $0) && pwd)

if [ "$(uname -s)" = "Darwin" ]; then
    $DOTPATH/script/tools/dump_mac_tools_config.sh

    log_section "Drift from [bootstrap.macos.defaults] (update config.macos.toml by hand):"
    python3 "$DOTPATH/script/tools/mac_defaults.py" report
fi

$DOTPATH/script/tools/dump_vscode_extensions.sh

log_section "Changes in dotfiles:"
git -C "$DOTPATH" status --short
