#!/bin/zsh

if ! command -v vp >/dev/null 2>&1; then
    curl -fsSL https://vite.plus | VP_NODE_MANAGER=yes bash
else
    vp upgrade
fi
