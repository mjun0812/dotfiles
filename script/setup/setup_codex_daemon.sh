#!/usr/bin/env zsh
set -euo pipefail

# setup_codex_daemon.sh <migrate|pin|run>
#
# Codex の常駐 app-server を `codex app-server daemon` で管理する。
# daemon は pidfile 管理の detached process で、reboot では復活しない。
# 起動は mise の user service (codex-app-server-daemon) が `run` を呼んで担う。
#
#   migrate  旧 launchd/systemd service (codex-remote-control) と、その postinstall が
#            張った ~/.codex/packages/standalone/current を片付ける。冪等。
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
migrate)
    mise bootstrap services remove codex-remote-control 2>/dev/null || true
    # 旧 daemon が残っていれば止める (旧 service の停止で通常は終了済み)
    daemon stop >/dev/null 2>&1 || true
    # daemon は standalone/current が残っていると旧 layout を使い続けるため、mise の install を指す link だけ消す
    current=${CODEX_HOME:-$HOME/.codex}/packages/standalone/current
    if [[ -L $current && $(readlink "$current") == */mise/installs/* ]]; then
        rm "$current"
    fi
    ;;
pin)
    daemon enable-remote-control
    daemon start
    daemon update --from-cli --yes
    ;;
run)
    daemon start
    exec sleep infinity
    ;;
*)
    echo "usage: $0 <migrate|pin|run>" >&2
    exit 2
    ;;
esac
