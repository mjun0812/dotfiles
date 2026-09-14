#!/bin/zsh

MISE_VERSION="2026.9.6"

if ! command -v mise >/dev/null 2>&1; then
    curl https://mise.run | MISE_VERSION="$MISE_VERSION" sh
else
    mise self-update -y "$MISE_VERSION"
    mise up
fi
