#!/bin/zsh

# is_exists returns true if executable $1 exists in $PATH
is_exists() {
    which "$1" >/dev/null 2>&1
    return $?
}

install_neovim() {
    if ! is_exists "nvim -v"; then
        mkdir -p ~/.bin
        curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage -o ~/.bin/nvim
        chmod u+x ~/.bin/nvim
    fi
}

install_neovim
