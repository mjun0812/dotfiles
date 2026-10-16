#!/usr/bin/env zsh
# worktreeの内容 (追跡中のファイルの現在の内容と、ignoreされていない未追跡ファイル) を表すtree hashを出力する。
# commitしても内容が変わらなければ同じ値になる。実際のindexは変更しない。
# usage: tree_fingerprint.sh <worktree>
# exit: 0 = 出力した、2 = 使い方の誤り、その他 = gitの失敗
set -euo pipefail

(($# == 1)) || {
    print -u2 "usage: ${0:t} <worktree>"
    exit 2
}
cd "$1"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
# 実際のindexを出発点にすると、変更の無いファイルを読み直さずに済む
index=$(git rev-parse --path-format=absolute --git-path index)
[[ -f $index ]] && cp "$index" "$tmpdir/index"
GIT_INDEX_FILE=$tmpdir/index git add -A
GIT_INDEX_FILE=$tmpdir/index git write-tree
