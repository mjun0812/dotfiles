#!/usr/bin/env zsh
set -euo pipefail

# Rift を mise の user service として常駐させる。
# Homebrew は install のたびに rift を ad-hoc 署名し直すので、版が上がるとアクセシビリティの許可を付け直す必要がある。

# mise の service は出力の行き先を持たないので、Rift 自身の service と同じ場所へ残す
exec >>"/tmp/rift_$(id -un).out.log" 2>>"/tmp/rift_$(id -un).err.log"

# launchd の PATH には Homebrew が無く、run_on_start の rift-cli が見つからない
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# opt は版をまたいで同じ場所を指すので、版が上がってもこのscriptを直さなくてよい
exec /opt/homebrew/opt/rift/bin/rift
