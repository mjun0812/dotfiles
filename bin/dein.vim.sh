#!/bin/zsh

install_dein() {
    mkdir -p ~/.cache
    sh -c "$(wget -O- https://raw.githubusercontent.com/Shougo/dein-installer.vim/master/installer.sh)"
}

install_dein
source ~/.zshrc
