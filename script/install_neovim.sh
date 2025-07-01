#!/bin/zsh


if ! command -v nvim >/dev/null 2>&1; then
    case `uname -s` in
        macOS)
            brew install neovim
            ;;
        Linux)
            echo "Install neovim"
            CURRENT=$(pwd)
            mkdir -p ~/.bin
            cd ~/.bin/
            curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
            chmod u+x ./nvim.appimage
            ./nvim.appimage --appimage-extract > /dev/null 2>&1
            ln -s ./squashfs-root/AppRun nvim
            rm -rf ~/.bin/nvim.appimage
            cd "$CURRENT"
        esac
fi

