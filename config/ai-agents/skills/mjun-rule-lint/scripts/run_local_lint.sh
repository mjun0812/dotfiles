#!/usr/bin/env zsh
# repositoryに含めないlocalのlint (<repo>/.mjun/lint/) を、<base> から追加・変更したファイルだけに実行する。
# 既存のコードにある違反で作業が止まらないよう、対象を今回の変更に絞る。
#   .mjun/lint/sgconfig.yml があれば、ast-grepのruleを実行する
#   .mjun/lint/scripts/*.sh があれば、それぞれを `zsh <script> <file>...` で実行する (違反は "<file>:<line>: <内容>" で出し、exit 1)
# usage:
#   run_local_lint.sh <repo-root> <base>   # <base> は比較の起点 (例: main、HEAD)。未追跡のファイルも対象にする
# exit: 0 = 違反なし (localのlintが無い場合を含む)、1 = 違反あり、2 = 使い方の誤り
set -euo pipefail
setopt null_glob

(($# == 2)) || {
    print -u2 "usage: ${0:t} <repo-root> <base>"
    exit 2
}
cd "$1"
base=$2
[[ -d .mjun/lint ]] || exit 0

# .mjun/ (worktreeではsymlink) はignoreの設定にかかわらず対象から外す
files=$({
    git diff --name-only --diff-filter=ACMR "$base"
    git ls-files --others --exclude-standard
} | grep -v -E '^\.mjun(/|$)' | sort -u || true)
[[ -n $files ]] || exit 0
targets=()
while IFS= read -r f; do targets+=("$f"); done <<<"$files"

result=0
if [[ -f .mjun/lint/sgconfig.yml ]]; then
    ast-grep scan -c .mjun/lint/sgconfig.yml "${targets[@]}" || result=1
fi
for script in .mjun/lint/scripts/*.sh; do
    zsh "$script" "${targets[@]}" || result=1
done
exit $result
