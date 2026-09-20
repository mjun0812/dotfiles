#!/bin/zsh
set -e

# Update through the official installer instead of `vp upgrade`: self-upgrade from vp <= 0.3.1 is blocked by
# minimumReleaseAge in non-interactive runs, while the installer hands setup off to the new binary
if command -v vp >/dev/null 2>&1 && ! vp upgrade --check 2>/dev/null | grep -q "Update available"; then
    exit 0
fi
curl -fsSL https://vite.plus | VP_NODE_MANAGER=yes bash
