#!/bin/zsh

if ! command -v vp >/dev/null 2>&1; then
    curl -fsSL https://vite.plus | bash
else
    vp upgrade
fi
