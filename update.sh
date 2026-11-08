#!/usr/bin/env zsh
#
# ローカルのapp設定をdotfilesへ逆同期する (install.shの対)。
# VSCode拡張リストを書き出し、macOSのapp設定はmiseの宣言とのずれを報告する。commitは行わない。

log_section() {
    print -P "%F{blue}%B==> %f%b%F{white}%B$1%f%b"
}

DOTPATH=$(cd $(dirname $0) && pwd)

if [ "$(uname -s)" = "Darwin" ]; then
    log_section "Drift from [bootstrap.macos.defaults] (update conf.d/macos-defaults.macos.toml by hand):"
    python3 "$DOTPATH/script/tools/mac_defaults.py"
fi

$DOTPATH/script/tools/dump_vscode_extensions.sh

log_section "Changes in dotfiles:"
git -C "$DOTPATH" status --short
