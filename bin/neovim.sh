#!/bin/zsh

CURRENT=$(pwd)
BIN_HOME=$(dirname $0)

source ${BIN_HOME}/get_os_info.sh

# is_exists returns true if executable $1 exists in $PATH
is_exists() {
    which "$1" >/dev/null 2>&1
    return $?
}

install_neovim() {
    if ! is_exists "nvim -v"; then
        case `uname -s` in
            macOS)
                brew install neovim
                ;;
            Linux)
                mkdir -p ~/.bin
                cd ~/.bin/
                curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
                chmod u+x ./nvim.appimage
                ./nvim.appimage --appimage-extract
                ln -s ./squashfs-root/AppRun nvim
                cd "$CURRENT"
            esac
    fi
}

install_neovim
