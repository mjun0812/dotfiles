#!/usr/bin/env zsh
# conf.d/dotfiles.tomlの宣言のうち、展開先がパターンに合うものだけを一時ディレクトリへ展開する。
# 宣言はmain checkout (~/.dotfiles) を指す絶対パスで書かれていて、worktreeの宣言はそのままでは展開できない。
# そこで、展開元を今のcheckout、展開先を一時ディレクトリへ書き換えたmise.tomlを作って適用する。
# usage: deploy_to_temp.sh <pattern> [<dir>]  (確かめるcheckoutの中で実行する)
#   <pattern>: 展開先の `~/` より後ろに、先頭から合わせる拡張正規表現。例: '\.(claude|codex)-pstack/'
#   <dir>: 展開先にするディレクトリ。省くと `mktemp -d` で作る
# 標準出力の最後の行に、展開先のディレクトリを出す。
set -euo pipefail

(($# >= 1)) || {
    print -u2 "usage: ${0:t} <pattern> [<dir>]"
    exit 2
}
repo=$(git rev-parse --show-toplevel)
dir=${2:-$(mktemp -d)}
entries=$(grep -E "^\"~/$1" $repo/config/dot_config/mise/conf.d/dotfiles.toml) || {
    print -u2 "パターンに合う宣言が無い: $1"
    exit 1
}

mkdir -p $dir
{
    print '[dotfiles]'
    print -r -- $entries | sed -e "s|~/.dotfiles|$repo|g" -e "s|\"~/|\"$dir/|g"
} >$dir/mise.toml

# マージの宣言は、キーの末尾 (`/dotfiles` など) が編集の名前なので、展開先のパスから外す
targets=(${(f)"$(print -r -- $entries |
    sed -E -e 's|^"~/([^"]+)/[^/"]+" = \{.*merge = true.*|\1|' -e 's|^"~/([^"]+)" = .*|\1|')"})

# 展開先を引数で渡さないと、実環境の宣言まで適用される
(cd $dir && MISE_TRUSTED_CONFIG_PATHS=$dir mise dot apply --yes ${targets/#/$dir/})
print -r -- $dir
