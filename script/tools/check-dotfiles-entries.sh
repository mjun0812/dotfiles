#!/usr/bin/env zsh
# config/dot と config/dot_config の直下のファイル・ディレクトリが、conf.d/dotfiles.toml に宣言されているかを検査する。
# 宣言が無いものは mise dot apply で展開されないので、足し忘れをprekで止める。
# ディレクトリはファイル単位のエントリ (例: herdr/config.toml) があれば宣言済みとみなす。

set -u

DOTPATH=${0:A:h:h:h}
declared=$(<"$DOTPATH/config/dot_config/mise/conf.d/dotfiles.toml")

result=0
for entry in "$DOTPATH"/config/dot/* "$DOTPATH"/config/dot_config/*; do
    relative=${entry#$DOTPATH/}
    if [[ $declared != *"\"~/.dotfiles/$relative\""* && $declared != *"\"~/.dotfiles/$relative/"* ]]; then
        print -u2 -- "conf.d/dotfiles.toml にエントリが無い: $relative"
        result=1
    fi
done
exit $result
