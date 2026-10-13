#!/usr/bin/env zsh
# config/ai-agents/textlint の設定とルールでtextlintを実行する。
# 使い方: textlint.sh <fix|report> [textlintの引数...]
#   fix:    自動修正できるルール (textlintrc.fix.json)
#   report: 自動修正できず、agentへ指摘を返すルール (textlintrc.report.json)
# 本体とルールは install.sh が bun install でこのディレクトリに入れる。

DOTPATH=${0:A:h:h:h}
textlint_dir="$DOTPATH/config/ai-agents/textlint"
config="$textlint_dir/textlintrc.$1.json"
shift

exec "$textlint_dir/node_modules/.bin/textlint" \
    --config "$config" \
    --rules-base-directory "$textlint_dir/node_modules" \
    "$@"
