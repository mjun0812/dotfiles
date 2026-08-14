#!/usr/bin/env zsh
set -euo pipefail

[[ $OSTYPE == darwin* ]] || exit 0

install_root="${1:-$MISE_TOOL_INSTALL_PATH}"
current="$HOME/.codex/packages/standalone/current"

/bin/mkdir -p "${current:h}"
/bin/ln -sfn bin/codex "$install_root/codex"
/bin/ln -sfn "$install_root" "$current"

"$current/codex" app-server daemon enable-remote-control >/dev/null
"$current/codex" app-server daemon restart >/dev/null
"$current/codex" app-server daemon version
