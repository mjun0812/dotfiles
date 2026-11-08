#!/usr/bin/env zsh
set -euo pipefail

# setup_codex_daemon.sh <pin|run>
#
# Codexの常駐app-serverを`codex app-server daemon`で管理する。
# daemonはpidfile管理のdetached processで、rebootでは復活しない。
# 起動はmiseのuser service (codex-app-server-daemon) が`run`を呼んで担う。
#
#   pin      mise管理のcodexをdaemonのpackageとして固定し、daemonを再起動する。
#            固定するとdaemon自身の自動更新が止まり、バージョンの権限はmiseだけになる。
#            codexのpostinstall (config/dot_config/mise/config.toml) とinstall.shから呼ぶ。
#   run      service本体。daemonを起動し、serviceが終了してprocessが回収されないよう待機する。

# zshenv経由でPATH (mise shims) を受け継ぎ、~/.zshrc.localからAPIキーなどをdaemonに渡す
[[ ! -f ~/.zshrc.local ]] || source ~/.zshrc.local

# miseのpostinstall中はMISE_TOOL_INSTALL_PATHのcodexを、それ以外はshimを使う
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
