#!/bin/zsh

install_dein() {
    mkdir -p ~/.cache
    curl https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.sh >installer.sh
    sh ./installer.sh ~/.cache/dein
    rm -f ./installer.sh
}

install_dein
source ~/.zshrc
