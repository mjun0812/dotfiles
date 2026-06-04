#!/usr/bin/env zsh

DOTPATH=$(cd $(dirname $0)/.. && pwd)
COMPLETIONS_DIR="$DOTPATH/config/dot_config/zsh_completions"
mkdir -p "$COMPLETIONS_DIR"

print -P "%F{blue}%B==> %f%b%F{white}%BUpdating zsh completions...%f%b"

if command -v kubectl >/dev/null 2>&1; then
    kubectl completion zsh > "$COMPLETIONS_DIR/_kubectl"
    echo "Updated: _kubectl ($(kubectl version --client -o json 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin)["clientVersion"]["gitVersion"])' 2>/dev/null || echo 'unknown version'))"
fi

if command -v docker >/dev/null 2>&1; then
    docker completion zsh > "$COMPLETIONS_DIR/_docker"
    echo "Updated: _docker ($(docker version --format '{{.Client.Version}}' 2>/dev/null || echo 'unknown version'))"
fi
