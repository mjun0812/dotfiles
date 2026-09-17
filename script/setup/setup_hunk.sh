#!/usr/bin/env bash
set -euo pipefail

# setup_hunk.sh
#
# hunk の managed extension (hunk-gh: `hunk gh pr <N>` で GitHub PR を開く) を
# install する。mise の postinstall (config/dot_config/mise/config.toml) から
# hunk の install / upgrade 時に呼ばれ、install.sh からも呼ばれる。
#
# `hunk extension install` は install 済みだと exit 1 で終了するため、
# `hunk extension list` で有無を確認してから install する。
# 実体は ~/.config/hunk/extensions/installed/<name>/ に clone される。

if hunk extension list 2>/dev/null | grep -q '^hunk-gh'; then
    echo "hunk-gh is already installed"
else
    hunk extension install modem-dev/hunk-gh --yes
fi
