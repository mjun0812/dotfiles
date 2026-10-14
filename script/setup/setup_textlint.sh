#!/usr/bin/env zsh
# textlint本体・ルールのinstallはmiseが担当する。ここでは共通設定と旧リンクだけを移行する。

set -eu

DOTPATH=${0:A:h:h:h}
textlint_prefix=$(cd "$DOTPATH" && mise where npm:textlint) || exit 1
if [[ ! -x "$textlint_prefix/bin/textlint" ]]; then
    print -u2 -- "textlint is not installed. Run: mise install npm:textlint"
    exit 1
fi

# dotfilesが作った旧リンクだけを外す。壊れたリンクも対象にし、手製のCLIは残す。
legacy_cli="$HOME/.local/bin/textlint"
if [[ -L $legacy_cli && $(readlink "$legacy_cli") == "$DOTPATH/config/textlint/node_modules/.bin/textlint" ]]; then
    rm -f -- "$legacy_cli"
fi
ln -snfv "$DOTPATH/config/textlint/textlintrc.js" "$HOME/.textlintrc.js"
