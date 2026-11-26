#!/usr/bin/env zsh
# rtkのOpenCode用plugin (~/.config/opencode/plugins/rtk.ts) を置く。
# miseのpostinstall (config/dot_config/mise/config.toml) からrtkのinstall / upgrade時に呼ばれ、install.shからも呼ばれる。
# rtk.tsは入っているrtkの版に合わせて生成されるshimなので、git管理に入れず、rtkの更新のたびに作り直す。
#
# --hook-onlyと--no-patchを外すと、rtkはClaude Codeの設定 (~/.claude/settings.json、~/.claude/CLAUDE.md) も書き換える。
# どちらもdotfilesへのsymlinkなので、書き換えはrepositoryのファイルを変えてしまう。
#
# rtkの標準出力は捨てる。Claude Codeの設定へhookを手で足すよう求める案内が出るが、hookはdotfilesの設定に宣言済みで、従う必要が無い。

set -eu

rtk init -g --opencode --hook-only --no-patch >/dev/null
