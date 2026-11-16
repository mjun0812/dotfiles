#!/usr/bin/env zsh
set -euo pipefail

[[ "$(uname -s)" == "Darwin" ]] || exit 0

DOTPATH=${0:A:h:h:h}
MOZC_DIR="$HOME/Library/Application Support/Mozc"
mkdir -p "$MOZC_DIR"
# Mozkeyは保存時にファイルを置き換えるので、symlinkではなく実ファイルを配置する。
cp "$DOTPATH/config/mac/mozkey/config1.db" "$MOZC_DIR/config1.db"
echo "Copied Mozkey settings. Restart Mozkey to load them."
