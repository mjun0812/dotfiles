#!/bin/zsh

case `uname -s` in
    Darwin)
        if ! command -v nvim >/dev/null 2>&1; then
            brew install neovim
        fi
        ;;
    Linux)
        CURRENT="$(pwd)"
        rm -rf ~/.local/bin/squashfs-root
        mkdir -p ~/.local/bin
        cd ~/.local/bin
        curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
        chmod u+x ./nvim.appimage
        ./nvim.appimage --appimage-extract > /dev/null 2>&1
        ln -s ./squashfs-root/AppRun nvim
        rm -rf ~/.local/bin/nvim.appimage
        cd "${CURRENT}"
        ;;
esac
