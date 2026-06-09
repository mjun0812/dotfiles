#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTPATH="$(cd "$SCRIPT_DIR/.." && pwd)"
EXTENSIONS_FILE="${1:-$DOTPATH/config/vscode/extensions.txt}"

if ! command -v code >/dev/null 2>&1; then
    echo "code command not found. Skipping VS Code extension install." >&2
    exit 0
fi

if [[ ! -f "$EXTENSIONS_FILE" ]]; then
    echo "VS Code extensions file not found: $EXTENSIONS_FILE" >&2
    exit 1
fi

failed_extensions=()

while IFS= read -r extension || [[ -n "$extension" ]]; do
    extension="${extension%%#*}"
    extension="${extension//[[:space:]]/}"

    if [[ -z "$extension" ]]; then
        continue
    fi

    if ! code --install-extension "$extension"; then
        failed_extensions+=("$extension")
    fi
done <"$EXTENSIONS_FILE"

if (( ${#failed_extensions[@]} > 0 )); then
    echo "Failed to install VS Code extensions:" >&2
    printf '  %s\n' "${failed_extensions[@]}" >&2
    exit 1
fi
