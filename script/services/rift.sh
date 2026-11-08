#!/usr/bin/env zsh
set -euo pipefail

# Riftをmiseのuser serviceとして常駐させる。
# Homebrewはinstallのたびにriftをad-hoc署名し直すので、版が上がるとアクセシビリティの許可を付け直す必要がある。

# miseのserviceは出力の行き先を持たないので、Rift自身のserviceと同じ場所へ残す
exec >>"/tmp/rift_$(id -un).out.log" 2>>"/tmp/rift_$(id -un).err.log"

# launchdのPATHにはHomebrewが無く、run_on_startのrift-cliが見つからない
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# optは版をまたいで同じ場所を指すので、版が上がってもこのscriptを直さなくてよい
exec /opt/homebrew/opt/rift/bin/rift
