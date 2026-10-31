#!/usr/bin/env zsh
set -euo pipefail

# setup_codex_daemon.sh <pin|run>
#
# Codex の常駐 app-server を `codex app-server daemon` で管理する。
# daemon は pidfile 管理の detached process で、reboot では復活しない。
# 起動は mise の user service (codex-app-server-daemon) が `run` を呼んで担う。
#
#   pin      mise 管理の codex を daemon の package として固定し、daemon を再起動する。
#            固定すると daemon 自身の自動更新が止まり、バージョンの権限は mise だけになる。
#            codex の postinstall (config/dot_config/mise/config.toml) と install.sh から呼ぶ。
#   run      service 本体。daemon を起動し、service が終了して process が回収されないよう待機する。

# zshenv 経由で PATH (mise shims) を受け継ぎ、~/.zshrc.local から API キーなどを daemon に渡す
[[ ! -f ~/.zshrc.local ]] || source ~/.zshrc.local

# mise の postinstall 中は MISE_TOOL_INSTALL_PATH の codex を、それ以外は shim を使う
codex=${MISE_TOOL_INSTALL_PATH:+$MISE_TOOL_INSTALL_PATH/codex}
codex=${codex:-$HOME/.local/share/mise/shims/codex}
daemon() { "$codex" app-server daemon "$@"; }

case ${1:-} in
pin)
    daemon enable-remote-control
    daemon start
    daemon update --from-cli --yes
    ;;
run)
    daemon start
    exec tail -f /dev/null
    ;;
*)
    echo "usage: $0 <pin|run>" >&2
    exit 2
    ;;
esac
