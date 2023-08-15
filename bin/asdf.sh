#!/bin/zsh

if [ -d ~/.asdf ]; then
    asdf update
else
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf
    . "$HOME/.asdf/asdf.sh"
    asdf plugin add golang
    asdf plugin add ruby
    asdf plugin add nodejs
    source ~/.zshrc
    asdf install
fi