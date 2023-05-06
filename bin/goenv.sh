#!/bin/zsh

# is_exists returns true if executable $1 exists in $PATH
is_exists() {
    which "$1" >/dev/null 2>&1
    return $?
}

install_goenv() {
    if [ -d ~/.goenv ]; then
        cd ~/.goenv && git fetch --all && git pull
        cd ~/
    else
        git clone https://github.com/syndbg/goenv.git ~/.goenv
        source ~/.zshrc
    fi
}

install_goenv
goenv install --skip-existing "$1"
goenv global "$1"

