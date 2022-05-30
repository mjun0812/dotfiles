#!/bin/zsh

install_nodenv() {
    if [ -d ~/.nodenv ]; then
        nodenv update
    else
        git clone https://github.com/nodenv/nodenv.git ~/.nodenv
        ~/.nodenv/bin/nodenv init
        source ~/.zshrc
        mkdir -p ~/.nodenv/plugins
        git clone https://github.com/nodenv/node-build.git ~/.nodenv/plugins/node-build
        git clone https://github.com/nodenv/nodenv-update.git ~/.nodenv/plugins/nodenv-update
    fi
}

install_nodenv
source ~/.zshrc
nodenv install --skip-existing "$1"
nodenv global "$1"

