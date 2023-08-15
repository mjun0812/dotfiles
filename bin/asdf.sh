#!/bin/zsh

if [ -d ~/.asdf ]; then
    asdf update
else
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf
    source ~/.zshrc
    asdf install
fi