#!/bin/zsh

# is_exists returns true if executable $1 exists in $PATH
is_exists() {
    which "$1" >/dev/null 2>&1
    return $?
}

install_nodenv() {
    if [ -d ~/.nodenv ]; then
    else
        git clone https://github.com/nodenv/nodenv.git ~/.nodenv
        ~/.nodenv/bin/nodenv init
        source ~/.zshrc
        mkdir -p ~/.nodenv/plugins
        git clone https://github.com/nodenv/node-build.git ~/.nodenv/plugins/node-build
    fi
}

install_nodenv
source ~/.zshrc
nodenv install 12.18.4
nodenv global 12.18.4
npm install -g yarn neovim
