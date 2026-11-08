#!/usr/bin/env bash
set -euo pipefail

# setup_hunk.sh
#
# hunkのmanaged extension (hunk-gh: `hunk gh pr <N>`でGitHub PRを開く) を
# installする。miseのpostinstall (config/dot_config/mise/config.toml) から
# hunkのinstall / upgrade時に呼ばれ、install.shからも呼ばれる。
#
# `hunk extension install`はinstall済みだとexit 1で終了するため、
# `hunk extension list`で有無を確認してからinstallする。
# 実体は~/.config/hunk/extensions/installed/<name>/にcloneされる。

if hunk extension list 2>/dev/null | grep -q '^hunk-gh'; then
    echo "hunk-gh is already installed"
else
    hunk extension install modem-dev/hunk-gh --yes
fi
