#!/usr/bin/env zsh
# config/textlint の設定と、miseが管理する本体・ルールでtextlintを実行する。
# 使い方: textlint.sh <fix|report> [textlintの引数...]
#   fix:    自動修正できるルール (textlintrc.fix.json)
#   report: 自動修正できず、agentへ指摘を返すルール (textlintrc.report.json)

set -eu

if (($# == 0)) || [[ $1 != fix && $1 != report ]]; then
    print -u2 -- "Usage: $0 <fix|report> [textlint options...]"
    exit 2
fi

DOTPATH=${0:A:h:h:h}
config="$DOTPATH/config/textlint/textlintrc.$1.json"
shift

# 呼び出し元のprojectではなく、dotfilesのglobal tool構成から解決する。
textlint_prefix=$(cd "$DOTPATH" && mise where npm:textlint) || exit 2

exec "$textlint_prefix/bin/textlint" \
    --config "$config" \
    --rules-base-directory "$textlint_prefix/node_modules" \
    "$@"
