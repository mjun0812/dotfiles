#!/usr/bin/env zsh
set -euo pipefail

# Playwriter の拡張機能入りブラウザを、保存先を固定した profile で常駐させる。
# `playwriter browser start` はブラウザを切り離して起動してすぐ終了するため、
# systemd が見張れるようにブラウザが終了するまでこのスクリプトが待つ。

output=$(playwriter browser start "$@")
print -r -- "$output"

if [[ ! $output =~ 'Browser started \(pid ([0-9]+)\)' ]]; then
    print -u2 "playwriter-browser: browser pid not found in the output"
    exit 1
fi

tail --pid="${match[1]}" -f /dev/null
