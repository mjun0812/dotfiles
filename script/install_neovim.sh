#!/bin/zsh

case `uname -s` in
    Darwin)
        if ! command -v nvim >/dev/null 2>&1; then
            brew install neovim
        fi
        ;;
    Linux)
	URL=$(curl -sSL https://api.github.com/repos/neovim/neovim/releases/latest | jq -r '.. | .browser_download_url? // empty' | grep 'nvim-linux-x86_64.appimage$')
	rm -rf ~/.local/bin/nvim
        mkdir -p ~/.local/bin
        curl -o ~/.local/bin/nvim -L $URL
        chmod u+x ~/.local/bin/nvim
        cd "${CURRENT}"
        ;;
esac
