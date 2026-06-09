#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTPATH="$(cd "$SCRIPT_DIR/.." && pwd)"
EXTENSIONS_FILE="$DOTPATH/config/vscode/extensions.txt"

if ! command -v code >/dev/null 2>&1; then
    echo "code command not found. Install VS Code shell command first." >&2
    exit 1
fi

mkdir -p "$(dirname "$EXTENSIONS_FILE")"
code --list-extensions 2>/dev/null | sort -u >"$EXTENSIONS_FILE"
echo "Dumped VS Code extensions to $EXTENSIONS_FILE"
