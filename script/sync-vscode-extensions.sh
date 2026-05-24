#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: script/sync-vscode-extensions.sh [--dry-run] [extensions-file]

Synchronize installed VS Code extensions with extensions-file.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTPATH="$(cd "$SCRIPT_DIR/.." && pwd)"
EXTENSIONS_FILE="$DOTPATH/config/vscode/extensions.txt"
EXTENSIONS_FILE_SET=0
DRY_RUN=0

while (($# > 0)); do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            if ((EXTENSIONS_FILE_SET)); then
                echo "Extensions file is already specified: $EXTENSIONS_FILE" >&2
                usage >&2
                exit 1
            fi
            EXTENSIONS_FILE="$1"
            EXTENSIONS_FILE_SET=1
            shift
            ;;
    esac
done

if ! command -v code >/dev/null 2>&1; then
    echo "code command not found. Install VS Code shell command first." >&2
    exit 1
fi

if [[ ! -f "$EXTENSIONS_FILE" ]]; then
    echo "VS Code extensions file not found: $EXTENSIONS_FILE" >&2
    exit 1
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

desired_extensions="$TEMP_DIR/desired"
installed_extensions="$TEMP_DIR/installed"
extensions_to_install="$TEMP_DIR/to-install"
extensions_to_uninstall="$TEMP_DIR/to-uninstall"

awk '
{
    sub(/#.*/, "")
    gsub(/[[:space:]]/, "")
    if ($0 != "") {
        print
    }
}
' "$EXTENSIONS_FILE" | sort -u >"$desired_extensions"

code --list-extensions 2>/dev/null | awk '
{
    gsub(/[[:space:]]/, "")
    if ($0 != "") {
        print
    }
}
' | sort -u >"$installed_extensions"

comm -23 "$desired_extensions" "$installed_extensions" >"$extensions_to_install"
comm -13 "$desired_extensions" "$installed_extensions" >"$extensions_to_uninstall"

if [[ ! -s "$extensions_to_install" && ! -s "$extensions_to_uninstall" ]]; then
    echo "VS Code extensions are already synchronized."
    exit 0
fi

if [[ -s "$extensions_to_install" ]]; then
    echo "VS Code extensions to install:"
    sed 's/^/  /' "$extensions_to_install"
fi

if [[ -s "$extensions_to_uninstall" ]]; then
    echo "VS Code extensions to uninstall:"
    sed 's/^/  /' "$extensions_to_uninstall"
fi

if ((DRY_RUN)); then
    echo "Dry-run mode. No VS Code extensions were installed or uninstalled."
    exit 0
fi

failed_installs=()
failed_uninstalls=()

while IFS= read -r extension || [[ -n "$extension" ]]; do
    if [[ -z "$extension" ]]; then
        continue
    fi

    if ! code --install-extension "$extension"; then
        failed_installs+=("$extension")
    fi
done <"$extensions_to_install"

while IFS= read -r extension || [[ -n "$extension" ]]; do
    if [[ -z "$extension" ]]; then
        continue
    fi

    if ! code --uninstall-extension "$extension"; then
        failed_uninstalls+=("$extension")
    fi
done <"$extensions_to_uninstall"

if (( ${#failed_installs[@]} > 0 || ${#failed_uninstalls[@]} > 0 )); then
    if (( ${#failed_installs[@]} > 0 )); then
        echo "Failed to install VS Code extensions:" >&2
        printf '  %s\n' "${failed_installs[@]}" >&2
    fi

    if (( ${#failed_uninstalls[@]} > 0 )); then
        echo "Failed to uninstall VS Code extensions:" >&2
        printf '  %s\n' "${failed_uninstalls[@]}" >&2
    fi

    exit 1
fi

echo "VS Code extensions synchronized."
