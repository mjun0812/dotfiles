#!/bin/zsh

if ! command -v mise >/dev/null 2>&1; then
    curl https://mise.run | sh
else
    mise self-update -y
    mise up
fi

source ~/.zshrc